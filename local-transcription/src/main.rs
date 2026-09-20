//! Streams desktop audio to the local Confucius4-R2T2 service.

use std::fs::File;
use std::io::BufWriter;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context as _, Result, bail};
use clap::{Parser, ValueEnum};
use futures_util::{Sink, SinkExt as _, Stream, StreamExt as _};
use hound::{SampleFormat, WavSpec, WavWriter};
use serde_json::{Value, json};
use tokio::io::AsyncReadExt as _;
use tokio::process::{Child, ChildStdout, Command};
use tokio::signal::unix::{SignalKind, signal};
use tokio::time::timeout;
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::{Error as WebSocketError, Message};

const SAMPLE_RATE: u32 = 16_000;
const CHANNELS: u16 = 1;
const CHUNK_MILLISECONDS: usize = 160;
const BYTES_PER_SAMPLE: usize = 2;
const FRAME_BYTES: usize = SAMPLE_RATE as usize * CHUNK_MILLISECONDS / 1_000 * BYTES_PER_SAMPLE;
const END_OF_STREAM: &str = "YOUDAO_ONETIME_ASR_STREAM_EOS";

#[derive(Clone, Copy, Debug, ValueEnum)]
enum AudioSource {
    Microphone,
    Meeting,
}

#[derive(Debug, Parser)]
#[command(version, about)]
struct Args {
    /// Capture only the default microphone or mix it with the default output monitor.
    #[arg(long, value_enum)]
    source: AudioSource,

    /// Append recognized text to this UTF-8 file.
    #[arg(long)]
    transcript: PathBuf,

    /// Save captured meeting audio as a mono 16 kHz WAV file.
    #[arg(long)]
    audio_output: Option<PathBuf>,

    /// Force a spoken language (e.g. German, English); omit to auto-detect.
    #[arg(long)]
    language: Option<String>,

    /// Local Confucius4-R2T2 WebSocket endpoint.
    #[arg(long, default_value = "ws://127.0.0.1:8272/asr_stream_api_v1")]
    uri: String,
}

#[derive(Debug)]
struct Recorder {
    child: Child,
    stdout: ChildStdout,
}

impl Recorder {
    fn start(device: &str) -> Result<Self> {
        let mut child = Command::new("parec")
            .args([
                format!("--device={device}"),
                "--format=s16le".to_owned(),
                format!("--rate={SAMPLE_RATE}"),
                format!("--channels={CHANNELS}"),
                "--raw".to_owned(),
                // parec's default buffering hides up to a second of audio from us; the
                // shorter the buffer, the less the drain below has to recover.
                format!("--latency-msec={CHUNK_MILLISECONDS}"),
            ])
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .with_context(|| format!("starting PulseAudio capture for {device}"))?;
        let stdout = child
            .stdout
            .take()
            .context("parec started without a stdout pipe")?;
        Ok(Self { child, stdout })
    }

    async fn read_frame(&mut self) -> Result<Vec<u8>> {
        let mut frame = vec![0_u8; FRAME_BYTES];
        self.stdout
            .read_exact(&mut frame)
            .await
            .context("reading a 160 ms audio frame from parec")?;
        Ok(frame)
    }

    /// Stops the recording and returns whatever PulseAudio had already buffered.
    /// Without this the last word of a sentence is lost whenever capture is stopped
    /// shortly after speaking.
    async fn drain(&mut self) -> Result<Vec<u8>> {
        if self
            .child
            .try_wait()
            .context("checking parec process state")?
            .is_none()
        {
            self.child.start_kill().context("stopping parec")?;
        }
        let mut tail = Vec::new();
        self.stdout
            .read_to_end(&mut tail)
            .await
            .context("draining buffered audio from parec")?;
        self.child
            .wait()
            .await
            .context("waiting for parec to stop")?;
        tail.truncate(tail.len() - tail.len() % BYTES_PER_SAMPLE);
        Ok(tail)
    }
}

#[derive(Debug)]
enum Capture {
    Microphone(Recorder),
    Meeting {
        microphone: Recorder,
        output_monitor: Recorder,
    },
}

impl Capture {
    async fn start(source: AudioSource) -> Result<Self> {
        match source {
            AudioSource::Microphone => Ok(Self::Microphone(Recorder::start("@DEFAULT_SOURCE@")?)),
            AudioSource::Meeting => {
                let sink = Command::new("pactl")
                    .arg("get-default-sink")
                    .output()
                    .await
                    .context("querying the default audio output")?;
                if !sink.status.success() {
                    bail!(
                        "pactl get-default-sink failed: {}",
                        String::from_utf8_lossy(&sink.stderr).trim()
                    );
                }
                let sink = String::from_utf8(sink.stdout)
                    .context("default sink name was not UTF-8")?
                    .trim()
                    .to_owned();
                if sink.is_empty() {
                    bail!("PipeWire reported no default audio output");
                }

                let microphone = Recorder::start("@DEFAULT_SOURCE@")?;
                let output_monitor = match Recorder::start(&format!("{sink}.monitor")) {
                    Ok(recorder) => recorder,
                    Err(error) => {
                        let mut microphone = microphone;
                        microphone.drain().await?;
                        return Err(error);
                    }
                };
                Ok(Self::Meeting {
                    microphone,
                    output_monitor,
                })
            }
        }
    }

    async fn next_frame(&mut self) -> Result<Vec<u8>> {
        match self {
            Self::Microphone(recorder) => recorder.read_frame().await,
            Self::Meeting {
                microphone,
                output_monitor,
            } => {
                let (microphone, output) =
                    tokio::try_join!(microphone.read_frame(), output_monitor.read_frame())?;
                Ok(mix_frames(&microphone, &output))
            }
        }
    }

    async fn drain(&mut self) -> Result<Vec<u8>> {
        match self {
            Self::Microphone(recorder) => recorder.drain().await,
            Self::Meeting {
                microphone,
                output_monitor,
            } => {
                let microphone = microphone.drain().await;
                let output = output_monitor.drain().await?;
                Ok(mix_frames(&microphone?, &output))
            }
        }
    }
}

fn mix_frames(microphone: &[u8], output: &[u8]) -> Vec<u8> {
    let mut mixed = Vec::with_capacity(FRAME_BYTES);
    let (microphone, _) = microphone.as_chunks::<BYTES_PER_SAMPLE>();
    let (output, _) = output.as_chunks::<BYTES_PER_SAMPLE>();
    for (microphone, output) in microphone.iter().zip(output) {
        let microphone = i16::from_le_bytes(*microphone);
        let output = i16::from_le_bytes(*output);
        // Equal-power source selection is impossible without level metadata. Averaging
        // keeps two loud meeting participants from clipping; either source alone is -6 dB.
        let sample = microphone.midpoint(output);
        mixed.extend_from_slice(&sample.to_le_bytes());
    }
    mixed
}

fn create_wav(path: &Path) -> Result<WavWriter<BufWriter<File>>> {
    WavWriter::create(
        path,
        WavSpec {
            channels: CHANNELS,
            sample_rate: SAMPLE_RATE,
            bits_per_sample: 16,
            sample_format: SampleFormat::Int,
        },
    )
    .with_context(|| format!("creating audio recording at {}", path.display()))
}

fn write_wav_frame(writer: &mut WavWriter<BufWriter<File>>, frame: &[u8]) -> Result<()> {
    let (samples, _) = frame.as_chunks::<BYTES_PER_SAMPLE>();
    for sample in samples {
        writer
            .write_sample(i16::from_le_bytes(*sample))
            .context("writing meeting audio")?;
    }
    Ok(())
}

fn request_id() -> Result<String> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .context("system clock predates the Unix epoch")?
        .as_nanos();
    Ok(format!("{}-{timestamp}", std::process::id()))
}

async fn handle_message(message: Message, transcript: &mut tokio::fs::File) -> Result<()> {
    if !message.is_text() {
        return Ok(());
    }
    let response: Value = serde_json::from_str(message.to_text().context("reading server text")?)
        .context("parsing the transcription server response")?;

    if response.get("status").and_then(Value::as_str) == Some("error") {
        bail!("transcription server rejected the stream: {response}");
    }

    if let Some(text) = response.pointer("/msg/text").and_then(Value::as_str)
        && !text.is_empty()
    {
        use tokio::io::AsyncWriteExt as _;
        transcript
            .write_all(text.as_bytes())
            .await
            .context("writing recognized text")?;
        transcript
            .flush()
            .await
            .context("flushing recognized text")?;
    }
    Ok(())
}

async fn finish_stream<S, R>(
    sender: &mut S,
    receiver: &mut R,
    transcript: &mut tokio::fs::File,
) -> Result<()>
where
    S: Sink<Message, Error = WebSocketError> + Unpin,
    R: Stream<Item = Result<Message, WebSocketError>> + Unpin,
{
    sender
        .send(Message::Text(END_OF_STREAM.into()))
        .await
        .context("sending end-of-stream marker")?;

    timeout(Duration::from_secs(45), async {
        while let Some(message) = receiver.next().await {
            handle_message(
                message.context("receiving final transcription")?,
                transcript,
            )
            .await?;
        }
        Result::<()>::Ok(())
    })
    .await
    .context("timed out waiting for the final transcription")??;
    Ok(())
}

#[tracing::instrument(skip_all, fields(source = ?args.source, transcript = %args.transcript.display()))]
async fn run(args: &Args) -> Result<()> {
    if let Some(parent) = args.transcript.parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .with_context(|| format!("creating transcript directory {}", parent.display()))?;
    }
    if let Some(path) = &args.audio_output
        && let Some(parent) = path.parent()
    {
        tokio::fs::create_dir_all(parent)
            .await
            .with_context(|| format!("creating recording directory {}", parent.display()))?;
    }

    let mut transcript = tokio::fs::File::create(&args.transcript)
        .await
        .with_context(|| format!("creating transcript at {}", args.transcript.display()))?;
    let mut wav = args.audio_output.as_deref().map(create_wav).transpose()?;
    let mut capture = Capture::start(args.source).await?;
    let (socket, _) = connect_async(&args.uri)
        .await
        .with_context(|| format!("connecting to {}", args.uri))?;
    let (mut sender, mut receiver) = socket.split();

    let header = json!({
        "channels": CHANNELS,
        "sample_rate": SAMPLE_RATE,
        "request_id": request_id()?,
        "language": args.language,
    });
    sender
        .send(Message::Text(header.to_string().into()))
        .await
        .context("sending transcription stream header")?;

    let mut terminate = signal(SignalKind::terminate()).context("installing SIGTERM handler")?;
    let mut interrupt = signal(SignalKind::interrupt()).context("installing SIGINT handler")?;
    let mut server_closed = false;

    loop {
        tokio::select! {
            _ = terminate.recv() => break,
            _ = interrupt.recv() => break,
            frame = capture.next_frame() => {
                let frame = frame?;
                if let Some(writer) = &mut wav {
                    write_wav_frame(writer, &frame)?;
                }
                sender
                    .send(Message::Binary(frame.into()))
                    .await
                    .context("streaming captured audio")?;
            }
            response = receiver.next() => {
                if let Some(response) = response {
                    let response = response.context("receiving streaming transcription")?;
                    if response.is_close() {
                        server_closed = true;
                        break;
                    }
                    handle_message(response, &mut transcript).await?;
                } else {
                    server_closed = true;
                    break;
                }
            }
        }
    }

    let tail = capture.drain().await?;
    if !server_closed && !tail.is_empty() {
        if let Some(writer) = &mut wav {
            write_wav_frame(writer, &tail)?;
        }
        for frame in tail.chunks(FRAME_BYTES) {
            sender
                .send(Message::Binary(frame.to_vec().into()))
                .await
                .context("streaming the final buffered audio")?;
        }
    }
    if !server_closed {
        finish_stream(&mut sender, &mut receiver, &mut transcript).await?;
    }
    if let Some(writer) = wav {
        writer.finalize().context("finalizing meeting audio")?;
    }
    tracing::info!("transcription capture stopped cleanly");
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();
    let args = Args::parse();
    run(&args).await
}

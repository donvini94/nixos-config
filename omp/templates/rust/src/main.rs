//! CHANGEME — one line on what this binary is for.

use anyhow::{Context as _, Result};
use clap::Parser;

/// CHANGEME — shown in `--help`.
#[derive(Debug, Parser)]
#[command(version, about)]
struct Args {
    /// Path to the input file.
    #[arg(long)]
    input: std::path::PathBuf,
}

fn main() -> Result<()> {
    // JSON when something other than a human reads stderr; RUST_LOG controls the filter.
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let args = Args::parse();
    run(&args)
}

#[tracing::instrument(skip_all, fields(input = %args.input.display()))]
fn run(args: &Args) -> Result<()> {
    // .context() says what we were doing, not what failed — the io error already knows
    // it was an io error.
    let body = std::fs::read_to_string(&args.input)
        .with_context(|| format!("reading input from {}", args.input.display()))?;

    tracing::info!(bytes = body.len(), "read input");
    println!("{}", body.len());
    Ok(())
}

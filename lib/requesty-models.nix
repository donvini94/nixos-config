{
  defaultModel = "deepinfra/deepseek-v4-flash-0731";

  # Verified against Requesty's authenticated model catalog on 2026-08-09.
  # Costs are USD per million tokens and are surfaced in OMP's model metadata.
  models = {
    "deepinfra/deepseek-v4-flash-0731" = {
      name = "DeepSeek V4 Flash 0731 — cheap default";
      context = 1048576;
      output = 65536;
      reasoning = true;
      cost = {
        input = 0.09;
        output = 0.18;
      };
    };
    "alibaba/qwen3.7-plus" = {
      name = "Qwen 3.7 Plus — cheap general agent";
      context = 1048576;
      output = 65536;
      reasoning = true;
      cost = {
        input = 0.32;
        output = 1.28;
      };
    };
    "deepinfra/deepseek-ai/DeepSeek-V4-Pro" = {
      name = "DeepSeek V4 Pro — stronger open model";
      context = 1048576;
      output = 65536;
      reasoning = false;
      cost = {
        input = 1.30;
        output = 2.60;
      };
    };
    "sference/kimi-k3" = {
      name = "Kimi K3 — open frontier model";
      context = 1048576;
      output = 131072;
      reasoning = true;
      cost = {
        input = 2.25;
        output = 11.25;
      };
    };
    "google/gemini-3.1-pro-preview" = {
      name = "Gemini 3.1 Pro — frontier comparison";
      context = 1048576;
      output = 65535;
      reasoning = true;
      cost = {
        input = 2.00;
        output = 12.00;
      };
    };
    "anthropic/claude-sonnet-5" = {
      name = "Claude Sonnet 5 — frontier comparison";
      context = 1000000;
      output = 128000;
      reasoning = true;
      cost = {
        input = 2.00;
        output = 10.00;
      };
    };
    "openai/gpt-5.6-terra" = {
      name = "GPT-5.6 Terra — balanced frontier comparison";
      context = 1050000;
      output = 128000;
      reasoning = true;
      cost = {
        input = 2.00;
        output = 12.00;
      };
    };
  };
}

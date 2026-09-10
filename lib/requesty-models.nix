{
  defaultModel = "deepseek/deepseek-v4.1-flash";

  # Costs are USD per million tokens and are surfaced in OMP's model metadata.
  models = {
    "deepseek/deepseek-v4.1-flash" = {
      name = "DeepSeek V4.1 Flash — cheap default";
      context = 1000000;
      output = 384000;
      reasoning = false;
      cost = {
        input = 0.30;
        output = 1.20;
      };
    };
    "alibaba/qwen3.8-flash" = {
      name = "Qwen 3.8 Flash — cheap general agent";
      context = 1048576;
      output = 131072;
      reasoning = true;
      cost = {
        input = 0.16;
        output = 0.47;
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
    "zai/glm-5.3" = {
      name = "GLM-5.3 — flagship coding/agent model";
      context = 1000000;
      output = 128000;
      reasoning = true;
      cost = {
        input = 1.40;
        output = 4.40;
      };
    };
    "zai/glm-5.3-flash" = {
      name = "GLM-5.3 Flash — cheap coding/agent model";
      context = 1000000;
      output = 128000;
      reasoning = true;
      cost = {
        input = 0.15;
        output = 0.50;
      };
    };
  };
}

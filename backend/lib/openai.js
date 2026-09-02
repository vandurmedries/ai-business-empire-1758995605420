const RESPONSES_URL = "https://api.openai.com/v1/responses";

export function extractOutputText(response) {
  if (typeof response?.output_text === "string") return response.output_text;
  const pieces = [];
  for (const item of response?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (content?.type === "output_text" && typeof content.text === "string") {
        pieces.push(content.text);
      }
    }
  }
  return pieces.join("");
}

export async function createStructuredResponse({ name, schema, instructions, input, env = process.env }) {
  if (!env.OPENAI_API_KEY) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 18_000);

  try {
    const response = await fetch(RESPONSES_URL, {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL || "gpt-5.6-luna",
        store: false,
        reasoning: { effort: "low" },
        instructions,
        input: JSON.stringify(input),
        text: {
          format: {
            type: "json_schema",
            name,
            strict: true,
            schema,
          },
        },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const detail = (await response.text()).slice(0, 300);
      throw new Error(`openai_http_${response.status}:${detail}`);
    }
    const payload = await response.json();
    const text = extractOutputText(payload);
    if (!text) throw new Error("openai_empty_output");
    return JSON.parse(text);
  } finally {
    clearTimeout(timeout);
  }
}

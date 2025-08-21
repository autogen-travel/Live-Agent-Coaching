import * as dasha from "@dasha.ai/sdk";

async function main() {
  const app = await dasha.deploy("./app", { groupName: "Default" });

  app.queue.on("ready", async (key, conv, info) => {
    console.log(info.sip);

    conv.audio.tts = "dasha";

    // Получаем API ключ из переменных окружения
    const openAiApiKey = process.env.OPENAI_API_KEY || null;
    
    const result = await conv.execute({ 
      channel: "audio",
      openAiApiKey: openAiApiKey
    });
    console.log(result.output);
  });

  await app.start();

  process.on("SIGINT", async () => {
    await app.stop();
    app.dispose();
  });

  console.log(`Waiting for calls`);
}

main();
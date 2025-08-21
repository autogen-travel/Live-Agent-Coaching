import * as dasha from "@dasha.ai/sdk";
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Получаем путь к текущему файлу
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Загружаем переменные из .env файла (с явным указанием пути)
const envPath = join(__dirname, '.env');
dotenv.config({ path: envPath });

async function main() {
  // Устанавливаем переменные окружения для Dasha SDK
  if (process.env.OPENAI_API_KEY) {
    process.env.DASHA_OPENAI_API_KEY = process.env.OPENAI_API_KEY;
  }

  const app = await dasha.deploy("./app", { groupName: "Default" });

  app.queue.on("ready", async (key, conv, info) => {
    console.log(info.sip);

    conv.audio.tts = "dasha";

    // Получаем API ключ из .env файла или переменных окружения
    const openAiApiKey = process.env.OPENAI_API_KEY || null;
    
    console.log("=== API Key Debug Info ===");
    console.log("OPENAI_API_KEY from process.env:", openAiApiKey ? "Set" : "Not set");
    console.log("DASHA_OPENAI_API_KEY from process.env:", process.env.DASHA_OPENAI_API_KEY ? "Set" : "Not set");
    console.log("API Key length:", openAiApiKey ? openAiApiKey.length : 0);
    console.log("API Key starts with:", openAiApiKey ? openAiApiKey.substring(0, 10) + "..." : "N/A");
    console.log("==========================");
    
    const result = await conv.execute({ 
      channel: "audio",
      openAiApiKey: openAiApiKey  // Передаем API ключ в параметры контекста
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
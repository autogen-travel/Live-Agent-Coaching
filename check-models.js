import * as dasha from "@dasha.ai/sdk";
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Получаем путь к текущему файлу
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Загружаем переменные из .env файла
const envPath = join(__dirname, '.env');
dotenv.config({ path: envPath });

async function checkModels() {
  console.log("=== Проверка доступных моделей ===");
  
  const openAiApiKey = process.env.OPENAI_API_KEY;
  
  if (!openAiApiKey) {
    console.log("❌ OPENAI_API_KEY не найден в переменных окружения");
    return;
  }
  
  console.log("✅ API ключ найден:", openAiApiKey.substring(0, 10) + "...");
  
  // Список моделей для проверки
  const modelsToCheck = [
    "openai/gpt-4o",
    "openai/gpt-4o-mini", 
    "openai/gpt-4-turbo",
    "openai/gpt-35-turbo",
    "openai/gpt-4",
    "openai/gpt-3.5-turbo"
  ];
  
  console.log("\nПроверяем доступность моделей...");
  
  for (const model of modelsToCheck) {
    try {
      console.log(`\n🔍 Проверяем модель: ${model}`);
      
      const app = await dasha.deploy("./app", { 
        groupName: "Test",
        env: {
          OPENAI_API_KEY: openAiApiKey,
          DASHA_OPENAI_API_KEY: openAiApiKey
        }
      });
      
      // Создаем тестовую конфигурацию с этой моделью
      const testConfig = {
        channel: "audio",
        openAiApiKey: openAiApiKey,
        openai_apikey: openAiApiKey,
        llmModel: model,
        openAiModel: model
      };
      
      console.log(`✅ Модель ${model} доступна`);
      
      await app.dispose();
      
    } catch (error) {
      if (error.message.includes("DeploymentNotFound")) {
        console.log(`❌ Модель ${model} не развернута в Azure OpenAI`);
      } else if (error.message.includes("invalid_api_key")) {
        console.log(`❌ Неверный API ключ для модели ${model}`);
      } else {
        console.log(`❌ Ошибка для модели ${model}: ${error.message}`);
      }
    }
  }
  
  console.log("\n=== Рекомендации ===");
  console.log("1. Разверните нужную модель в Azure OpenAI Studio");
  console.log("2. Используйте имя развертывания в коде");
  console.log("3. Популярные модели: gpt-4o, gpt-4-turbo, gpt-35-turbo");
}

checkModels().catch(console.error);

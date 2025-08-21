// Imports default features
import "./hello.dsl";
import "./conversation_analyzer.dsl";
import "./prompts.dsl";
import "./voicemail.dsl";
import "./interruptions.dsl";


context {
    // Settings
    isLabellingEnabled: boolean = false;                // Turns on labeling. Refer to conversation_analyzer.dsl for details on how it works.
    isFastVmDetectionEnabled: boolean = false;          // Turns on voicemail detection by GPT. Refer to voicemail.dsl for details on how it works.
    isTalkFirstEnabled: boolean = true;                // Allows Dasha to speak first in the conversation. If set to False, Dasha will wait for the user to speak before starting.
    defVADPauseLength: number = 0.5;                      // A multiplier for the default VADPauseLength of 0.8 seconds (the time waited after the user's phrase to allow for a potential longer response).


    // Your inputs
    input endpoint: string = "";
    input llmModel: string = "openai/gpt-5-nano";
    // API ключ должен быть установлен через переменную окружения OPENAI_API_KEY
    // или через конфигурацию Dasha
    input openAiApiKey: string? = null;
    input openAiModel: string = "openai/gpt-5-nano";

    // System variables
    finished: boolean = false;
    isFirstTurn: boolean = true;
    dialogueTimer: string = "";
    maxDialogueDuration: number = 5*60*1000; // This parameter sets the maximum duration of the dialogue. It exists for various reasons (e.g., to mitigate damage from unforeseen errors). It is set to 5 minutes by default and can be adjusted if necessary.

    top_p: number = 0.1;
}

// This is the start node named "root" - this node initiates the conversation.
// For more information on nodes, visit: https://docs.dasha.ai/en-us/default/dasha-script-language/program-structure#node
start node root
{    
    do
    {
        
        // TrackEvent lines are used for tracking specific events that occur during a conversation. They help simplify later conversation review and statistics collection.
        // You can find all tracked events on your Playground page, in the Events tab: https://playground.dasha.ai/events
        // For example, if this call started but the connection didn't go through for any reason, you would only see the "Captured" event on your Events tab.
        #trackEvent("Captured");

        // This function is responsible for connecting Dasha to a call.
        // For more information on this function, visit: https://docs.dasha.ai/en-us/default/dasha-script-language/built-in-functions/#session-control
        #connectSafe($endpoint, options:
          {
            cache_tts_before_connect: "false",
            vad: "asap_v1"
          }
        );

        #noiseControl(false);

        #trackEvent("Connected"); 

        #log(#getConnectOptions());
        
        set $dialogueTimer = #startTimer($maxDialogueDuration);

        // In cases where the dialogue doesn't use voice (e.g., chat dialogue), this code disables Dasha's pings to check if the user is still present (phrases like "Hello?", "Are you there?").
        if(#getConnectOptions().options.sip_domain is null) {
          digression disable hello;
        }        

        if($isFastVmDetectionEnabled)  // Transition to a voicemail node if voicemail detection is enabled.
          goto vm;
        else if($isTalkFirstEnabled)   // If Dasha is allowed to speak first in the dialogue, transitions to the "main loop" node.
          goto main_loop;
        else {                         // If Dasha isn't allowed to speak first or voicemail detection isn't enabled, waits for the user's phrase.
          wait *;
        }
    }
    transitions
    {
      vm: goto vm; // This node can be found in voicemail.dsl.
      main_loop: goto main_loop;
      proceed: goto main_loop on true;
    }
}

node main_loop
{
    do
    {
      
        // Necessary for conversation_analyzer. It is used to format the dialogue for the GPT analyzer for labeling.
        $convlog.push({role: "user", message: #getMessageText()});

        $.checkSmartInterruption(); // Turns on smart interruptions. For more information on how it works, refer to interruptions.dsl.
        
         var gptOptions = $openAiApiKey is not null ? {
            model: $openAiModel,
            openai_apikey: $openAiApiKey,
            top_p: $top_p
        } : {
            model: $llmModel,
            top_p: $top_p
        };

        // This is your main function. It is responsible for the majority of the dialogue. In it, you can see a prompt for GPT ($prompt, which can be found and changed in prompts.dsl) and options for this function.
        // Feel free to modify this part as needed based on your experience.
        // For more information on this function, visit: https://docs.dasha.ai/en-us/default/dasha-script-language/built-in-functions/#gpt
        var a = #answerWithGPT($prompt, interruptible:true, gptOptions: gptOptions,
          sayOptions: {
            interruptDelay: 1.0,
            fillerTexts: [
              "Хм...",
              "окей...",
              "так...",
              "э...",
              "хорошо...",
              "понятно..."
            ],
            fillerSpeed: 1.0,
            fillerDelay: 2.0,
            fillerStartDelay: $isFirstTurn?10.0:1.0
        });

        #log("Answered with gpt");

        $convlog.push({role: "assistant", message: a.saidPhrase});

        if ($finished) { 
            $.onExit(); // This part tracks the "GPT" event, logs, and labels the conversation when the dialogue concludes naturally.
            #trackEvent("GPT", #getVisitCount("main_loop").toString());

            exit;
        }        
        // This code is used when GPT calls a function. The retry is necessary to obtain a response from GPT with updated information from the called function(s).
        if (a.functionCalled) {
          #log("Called a chat function, retry");
          goto retry;
        }

        $.handleInterruption(a.interrupted); // This function is responsible for handling interruption. This function is set in interruptions.dsl

        if($isFirstTurn) {
          set $isFirstTurn = false;
        }

        wait *;
    } transitions {
        main_loop: goto main_loop on true;
        retry: goto main_loop;
    }
}

// This digression handles ending the dialogue, logging the conversation, and labeling it when the conversation is finished by the user instead of Dasha.
global digression main_loop_dig
{
    conditions { on true tags: onclosed; }
    do
    {
        $.onExit();
        #trackEvent("GPT", #getVisitCount("main_loop").toString());
        #trackEvent("UserHangup");
        exit;
    }
}

// This digression ends the call with a "TimeOut" status if the call duration exceeds the maximum set in maxDialogueDuration.
digression dialogue_duration_time_exceeded
{
    conditions
    {
        on #isTimerExpired($dialogueTimer) tags: ontick;
    }
    do
    {
        set $status = "TimeOut";
        #log("DIALOGUE TIMER EXCEEDED");
        #trackEvent("DialogueTimerExceeded");

        exit;
    }
}


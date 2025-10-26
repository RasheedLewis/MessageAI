const { functions } = require("../app");
const { chatCompletion, DEFAULT_MODEL } = require(
    "../services/openai-service",
);
const { ToneLevel, ResponseFormat } = require(
    "../types/response-generation",
);
const { logError } = require("../logger");

const FALLBACK_TONE = ToneLevel.FRIENDLY;
const FALLBACK_FORMAT = ResponseFormat.PARAGRAPH;
const MAX_HISTORY_COUNT = 8;

const formatContextSummary = (context = {}) => {
    const { category, sentiment, priority } = context;
    const pieces = [];

    if (category) {
        pieces.push(`Conversation category: ${category}.`);
    }

    if (sentiment) {
        pieces.push(`Current sentiment: ${sentiment}.`);
    }

    if (typeof priority === "number") {
        pieces.push(`Priority score: ${priority}.`);
    }

    return pieces.length > 0 ? pieces.join(" ") : "";
};

const buildSystemPrompt = (creatorProfile = {}, conversationContext = {}) => {
    const name = creatorProfile.displayName || "Creator";
    const persona = creatorProfile.persona || "Engaging content creator";
    const tone = creatorProfile.defaultTone || FALLBACK_TONE;
    const styleGuidelines = Array.isArray(creatorProfile.styleGuidelines) ?
        creatorProfile.styleGuidelines :
        [];
    const voiceSamples = Array.isArray(creatorProfile.voiceSamples) ?
        creatorProfile.voiceSamples :
        [];
    const signature = creatorProfile.signature || "";

    const styleSection = styleGuidelines.length > 0 ?
        `Style Guidelines:\n- ${styleGuidelines.join("\n- ")}` :
        "Style Guidelines: Maintain authenticity and warmth.";

    const samplesSection = voiceSamples.length > 0 ?
        `Voice Samples:\n${voiceSamples.map((sample, index) => {
            return `${index + 1}. ${sample}`;
        }).join("\n")}` :
        "Voice Samples:\n1. Hey hey! Thanks so much for reaching out—this totally made my day!";

    const signatureSection = signature ?
        `Signature Close:
${signature}` :
        "";

    const contextSummary = formatContextSummary(conversationContext);

    return [
        `${name} Persona: ${persona}.`,
        `Default Tone: ${tone}.`,
        styleSection,
        samplesSection,
        signatureSection,
        contextSummary,
        "",
        "You must respond with JSON matching strictly the schema:",
        "type GeneratedReply = {",
        "  reply: string;",
        "  tone: \"casual\" | \"friendly\" | \"professional\" | \"formal\";",
        "  format: \"text\" | \"bullet\" | \"paragraph\";",
        "  reasoning: string;",
        "  followUpQuestions: string[];",
        "  suggestedNextActions: string[];",
        "};",
        "",
        "Constraints:",
        "- reply must mirror the creator voice and remain concise (<= 200 words).",
        "- preserve authenticity; do not sound like a robot.",
        "- include emojis only if voice samples frequently use them.",
        "- do not invent facts or commit to unavailable things.",
        "- tone must align with user request urgency and relationship.",
        "- reasoning is a brief explanation for internal analytics (not shown).",
        "- followUpQuestions should capture any clarification needs or opportunities.",
        "- suggestedNextActions should be actionable bullet ideas for the creator.",
        "- Always output valid JSON with double quotes and no trailing comments.",
    ].join("\n");
};

const formatConversationHistory = (history = []) => {
    if (!Array.isArray(history) || history.length === 0) {
        return "No prior conversation history provided.";
    }

    const trimmed = history.slice(-MAX_HISTORY_COUNT);
    const formatted = trimmed.map((entry, index) => {
        const speaker = entry && entry.speaker ? entry.speaker : `Speaker ${index + 1}`;
        const content = entry && entry.content ? entry.content : "";
        return `${speaker}: ${content}`;
    });

    return formatted.join("\n\n");
};

const buildMessages = ({
    latestMessage,
    conversationHistory,
    creatorProfile,
    conversationContext = {},
    responsePreferences = {},
}) => {
    const systemContent = buildSystemPrompt(creatorProfile, conversationContext);
    const historyString = formatConversationHistory(conversationHistory);

    const preferredTone = responsePreferences.tone || creatorProfile.defaultTone;
    const preferredFormat = responsePreferences.format || creatorProfile.preferredFormat;

    const preferenceBlock = {
        preferredTone,
        preferredFormat,
        includeSignature: Boolean(responsePreferences.includeSignature ||
            creatorProfile.includeSignature),
        additionalNotes: responsePreferences.notes || "",
    };

    return [
        {
            role: "system",
            content: systemContent,
        },
        {
            role: "user",
            content: JSON.stringify({
                latestMessage,
                conversationHistory: historyString,
                preferences: preferenceBlock,
                metadata: conversationContext,
            }),
        },
    ];
};

const sanitizeTone = (tone) => {
    const tones = Object.values(ToneLevel);
    return tones.indexOf(tone) !== -1 ? tone : FALLBACK_TONE;
};

const sanitizeFormat = (format) => {
    const formats = Object.values(ResponseFormat);
    return formats.indexOf(format) !== -1 ? format : FALLBACK_FORMAT;
};

const sanitizeArray = (value) => {
    return Array.isArray(value) ? value : [];
};

const parseResponse = (raw) => {
    try {
        const parsed = JSON.parse(raw);
        const reply = typeof parsed.reply === "string" ? parsed.reply : "";
        const tone = sanitizeTone(parsed.tone);
        const format = sanitizeFormat(parsed.format);
        const reasoning = typeof parsed.reasoning === "string" ? parsed.reasoning : "";
        const followUpQuestions = sanitizeArray(parsed.followUpQuestions);
        const suggestedNextActions = sanitizeArray(parsed.suggestedNextActions);

        return {
            reply,
            tone,
            format,
            reasoning,
            followUpQuestions,
            suggestedNextActions,
        };
    } catch (error) {
        throw new Error("Failed to parse response JSON");
    }
};

module.exports = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentication required to generate response",
        );
    }

    const latestMessage = data && data.message ? data.message : null;
    if (!latestMessage || typeof latestMessage !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Message text is required for response generation",
        );
    }

    const conversationHistory = data && data.conversationHistory ?
        data.conversationHistory :
        [];
    const creatorProfile = data && data.creatorProfile ? data.creatorProfile : {};
    const responsePreferences = data && data.responsePreferences ?
        data.responsePreferences :
        {};

    try {
        const response = await chatCompletion({
            model: DEFAULT_MODEL,
            temperature: 0.6,
            messages: buildMessages({
                latestMessage,
                conversationHistory,
                creatorProfile,
                responsePreferences,
            }),
        });

        const choices = Array.isArray(response.choices) ? response.choices : [];
        let content = null;
        if (choices.length > 0) {
            const firstChoice = choices[0] || {};
            const messagePayload = firstChoice.message || {};
            if (typeof messagePayload.content === "string") {
                content = messagePayload.content;
            }
        }

        if (!content) {
            throw new Error("OpenAI returned empty response");
        }

        return parseResponse(content);
    } catch (error) {
        logError("generateResponse failed", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to generate response",
        );
    }
});


import { initAiSettings } from 'ee/ai/settings/index';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';

initAiSettings('js-ai-settings', AiGroupSettings, { isGroupSettings: true });

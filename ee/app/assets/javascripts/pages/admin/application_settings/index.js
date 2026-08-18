import '~/pages/admin/application_settings/index';
import { initAiSettings } from 'ee/ai/settings/index';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';
import { initMaxAccessTokenLifetime } from './account_and_limits';

initAiSettings('js-ai-settings', AiAdminSettings);
initMaxAccessTokenLifetime();

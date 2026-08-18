<script>
import OpenAgenticChatButton from 'ee/ai/shared/widgets/open_agentic_chat_button.vue';
import {
  registerExternalContextProvider,
  PERMISSIONS_FORM_CONTEXT_CATEGORY,
} from 'ee/ai/duo_agentic_chat/context/external_context_store';
import getAccessTokenPermissions from '~/personal_access_tokens/graphql/get_access_token_permissions.query.graphql';
import { ACCESS_SCOPE_KEYS } from '~/personal_access_tokens/constants';
import { emptyByScope } from '~/personal_access_tokens/utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { s__, __ } from '~/locale';

const AGENT = { name: __('Permissions Assistant') };
const TOOL_NAME = 'set_form_permissions';
const SCOPE_KEY_BY_BOUNDARY = {
  GROUP: 'namespace',
  PROJECT: 'namespace',
  USER: 'user',
  INSTANCE: 'instance',
};
const WELCOME_MESSAGE = s__(
  'AccessTokens|I am your fine-grained permissions assistant. I can help you choose the right permissions for your access token.',
);
const PREDEFINED_PROMPTS = [
  s__('AccessTokens|I want to read and write to repositories via the API.'),
  s__('AccessTokens|I need to manage CI/CD pipelines and read job logs.'),
  s__('AccessTokens|I want to automate issue and merge request management.'),
  s__('AccessTokens|I need read-only access to projects and groups.'),
];

export default {
  name: 'AskDapPermissions',
  components: {
    OpenAgenticChatButton,
  },
  inject: ['agenticAvailable'],
  props: {
    formPermissions: {
      type: Object,
      required: false,
      default: () => emptyByScope(),
    },
  },
  emits: ['permissions-selected', 'permissions-cleared'],
  data() {
    return {
      permissions: [],
      permissionsError: false,
      // Tool results are re-emitted when the chat reconnects and replays its history.
      // Track applied ones so a replayed suggestion never re-mutates the form.
      appliedToolMessageIds: new Set(),
    };
  },
  computed: {
    isLoaded() {
      return this.permissions.length > 0;
    },
    // Maps each permission name to the set of form scope keys its boundaries allow,
    // e.g. Map { 'read_api' => Set('namespace'), 'read_snippet' => Set('namespace', 'user') }.
    scopeKeysByName() {
      const result = new Map();

      this.permissions.forEach(({ name, boundaries }) => {
        const keys = new Set(
          (boundaries || []).map((boundary) => SCOPE_KEY_BY_BOUNDARY[boundary]).filter(Boolean),
        );
        result.set(name, keys);
      });

      return result;
    },
    resourceId() {
      return convertToGraphQLId(TYPENAME_USER, window.gon?.current_user_id);
    },
    buttonOptions() {
      return {
        disabled: this.permissionsError || !this.isLoaded,
        title: this.permissionsError ? this.$options.i18n.permissionsLoadError : undefined,
      };
    },
  },
  apollo: {
    permissions: {
      query: getAccessTokenPermissions,
      update(data) {
        return data?.accessTokenPermissions || [];
      },
      error() {
        this.permissionsError = true;
      },
    },
  },
  mounted() {
    this.disposeContextProvider = registerExternalContextProvider(
      PERMISSIONS_FORM_CONTEXT_CATEGORY,
      () => ({
        namespace: this.formPermissions.namespace,
        user: this.formPermissions.user,
        global: this.formPermissions.instance,
      }),
    );
  },
  beforeDestroy() {
    this.disposeContextProvider?.();
  },
  i18n: {
    buttonLabel: s__('AccessTokens|Add permissions with Duo'),
    permissionsLoadError: __('Unable to load permissions'),
  },
  methods: {
    handleToolCompleted({ name, args, messageId } = {}) {
      if (name !== TOOL_NAME || !args || typeof args !== 'object') return;

      if (messageId) {
        if (this.appliedToolMessageIds.has(messageId)) return;
        this.appliedToolMessageIds.add(messageId);
      }

      const selected = this.filterByBoundary(args.select);
      if (this.hasAny(selected)) {
        this.$emit('permissions-selected', selected);
      }

      const cleared = this.filterByBoundary(args.clear);
      if (this.hasAny(cleared)) {
        this.$emit('permissions-cleared', cleared);
      }
    },
    // Drop any name the agent placed in a section its boundaries don't allow. A name
    // may legitimately appear in several sections (e.g. read_snippet in user and namespace).
    filterByBoundary(selection) {
      const result = emptyByScope();
      if (!selection || typeof selection !== 'object') return result;

      ACCESS_SCOPE_KEYS.forEach((key) => {
        const gatewayKey = key === 'instance' ? 'global' : key;
        const names = Array.isArray(selection[gatewayKey]) ? selection[gatewayKey] : [];

        names.forEach((permissionName) => {
          const validKeys = this.scopeKeysByName.get(permissionName);
          if (validKeys?.has(key) && !result[key].includes(permissionName)) {
            result[key].push(permissionName);
          }
        });
      });

      return result;
    },
    hasAny(byScope) {
      return Object.values(byScope).some((names) => names.length > 0);
    },
  },
  AGENT,
  PREDEFINED_PROMPTS,
  WELCOME_MESSAGE,
};
</script>

<template>
  <li v-if="agenticAvailable" class="gl-ml-auto gl-flex gl-items-center gl-pl-3">
    <open-agentic-chat-button
      :button-text="$options.i18n.buttonLabel"
      :resource-id="resourceId"
      :agent="$options.AGENT"
      :welcome-message="$options.WELCOME_MESSAGE"
      :predefined-prompts="$options.PREDEFINED_PROMPTS"
      :button-options="buttonOptions"
      @tool-completed="handleToolCompleted"
    />
  </li>
</template>

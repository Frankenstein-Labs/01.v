<script>
import { GlButton, GlToastMixin } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import {
  testExistingMavenUpstreamWithOverrides,
  testMavenUpstream,
} from 'ee/api/virtual_registries_api';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'TestUpstreamButton',
  components: {
    GlButton,
  },
  mixins: [GlToastMixin],
  inject: {
    fullPath: {
      default: '',
    },
    testUpstreamMutation: {
      default: null,
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    url: {
      type: String,
      required: false,
      default: '',
    },
    username: {
      type: String,
      required: false,
      default: '',
    },
    password: {
      type: String,
      required: false,
      default: '',
    },
    upstreamId: {
      type: [Number, String],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isTesting: false,
    };
  },
  methods: {
    async testUpstreamRESTApi() {
      const { url, username, password, upstreamId } = this;

      let testFn;
      let args = {};
      const defaultArgs = {
        url,
        username,
        password,
      };
      if (upstreamId) {
        testFn = testExistingMavenUpstreamWithOverrides;
        args = {
          ...defaultArgs,
          id: getIdFromGraphQLId(upstreamId),
        };
      } else {
        testFn = testMavenUpstream;
        args = {
          ...defaultArgs,
          id: this.fullPath,
        };
      }

      const { data } = await testFn(args);

      return { success: data.success, error: data.result };
    },
    async testUpstreamGraphqlAPI() {
      const { data } = await this.$apollo.mutate({
        mutation: this.testUpstreamMutation,
        variables: {
          input: {
            id: this.upstreamId,
            url: this.url,
            username: this.username,
            password: this.password,
            groupPath: this.fullPath,
          },
        },
      });

      return { success: data.test.success, error: data.test.errors[0] };
    },
    async testUpstream() {
      try {
        this.isTesting = true;

        const data = await (this.testUpstreamMutation
          ? this.testUpstreamGraphqlAPI()
          : this.testUpstreamRESTApi());

        if (data.success) {
          this.$toast.show(s__('VirtualRegistry|Connection successful.'));
        } else {
          this.$toast.show(
            sprintf(s__('VirtualRegistry|Failed to connect %{msg}'), { msg: data.error }, false),
          );
        }
      } catch (error) {
        if (error.response?.status === 400 && typeof error.response?.data?.message === 'object') {
          const message = Object.entries(error.response.data.message)[0].join(' ');
          this.$toast.show(
            sprintf(s__('VirtualRegistry|Failed to connect %{msg}'), { msg: message }),
          );
        } else {
          this.$toast.show(s__('VirtualRegistry|Failed to connect.'));
          captureException({ error, name: this.$options.name });
        }
      } finally {
        this.isTesting = false;
      }
    },
  },
};
</script>

<template>
  <gl-button
    :disabled="disabled"
    :loading="isTesting"
    variant="confirm"
    category="tertiary"
    @click="testUpstream"
  >
    {{ s__('VirtualRegistry|Test upstream') }}
  </gl-button>
</template>

<script>
import { GlToggle, GlSprintf, GlLink, GlExperimentBadge } from '@gitlab/ui';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import getGroupVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_group_virtual_registries_setting.query.graphql';
import updateVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/mutations/update_virtual_registries_setting.mutation.graphql';
import { updateVirtualRegistriesSettingOptimisticResponse } from 'ee_component/packages_and_registries/settings/group/graphql/utils/optimistic_responses';
import { updateGroupVirtualRegistriesSetting } from 'ee_component/packages_and_registries/settings/group/graphql/utils/cache_update';
import CleanupPolicyDetails from 'ee_component/packages_and_registries/settings/group/components/cleanup_policy_details.vue';

export default {
  name: 'VirtualRegistriesSetting',
  components: {
    CleanupPolicyDetails,
    GlExperimentBadge,
    GlLink,
    GlSprintf,
    GlToggle,
    SettingsSection,
  },
  inject: ['groupPath'],
  emits: ['error', 'success'],
  apollo: {
    group: {
      query: getGroupVirtualRegistriesSetting,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      context: {
        batchKey: 'GroupPackagesSettings',
      },
    },
  },
  data() {
    return {
      group: {},
    };
  },
  computed: {
    virtualRegistriesSetting() {
      return this.group?.virtualRegistriesSetting || {};
    },
    isLoading() {
      return this.$apollo.queries.group.loading;
    },
    enabled: {
      get() {
        return Boolean(this.virtualRegistriesSetting.enabled);
      },
      set(enabled) {
        this.updateSettings({ enabled });
      },
    },
  },
  methods: {
    mutationVariables(payload) {
      return {
        input: {
          fullPath: this.groupPath,
          ...payload,
        },
      };
    },
    async executeMutation(config, resource) {
      try {
        const { data } = await this.$apollo.mutate(config);
        if (data[resource]?.errors.length > 0) {
          throw new Error();
        } else {
          this.$emit('success');
        }
      } catch {
        this.$emit('error');
      }
    },
    async updateSettings(payload) {
      const apolloConfig = {
        mutation: updateVirtualRegistriesSetting,
        variables: this.mutationVariables(payload),
        update: updateGroupVirtualRegistriesSetting(this.groupPath),
        optimisticResponse: updateVirtualRegistriesSettingOptimisticResponse({
          ...this.virtualRegistriesSetting,
          ...payload,
        }),
      };

      this.executeMutation(apolloConfig, 'updateVirtualRegistriesSetting');
    },
  },
};
</script>

<template>
  <settings-section
    :heading="s__('VirtualRegistry|Virtual registry')"
    :description="
      s__(
        'VirtualRegistry|Manage packages across multiple sources and streamline development workflows using virtual registries.',
      )
    "
    data-testid="virtual-registries-setting"
  >
    <gl-toggle
      v-model="enabled"
      :disabled="isLoading"
      data-testid="virtual-registries-setting-toggle"
    >
      <template #label>
        <span class="gl-flex gl-items-center">
          {{ s__('VirtualRegistry|Enable virtual registry') }}
          <gl-experiment-badge type="beta" class="gl-ml-2" />
        </span>
      </template>
      <template #help>
        <gl-sprintf
          :message="
            s__(
              'VirtualRegistry|When you enable this feature, you accept the %{linkStart}GitLab Testing Agreement.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link href="https://handbook.gitlab.com/handbook/legal/testing-agreement/">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
        <p class="gl-mb-0 gl-mt-3">
          {{
            s__(
              'VirtualRegistry|Disabling removes access. Existing registries are preserved and available again when re-enabled.',
            )
          }}
        </p>
      </template>
    </gl-toggle>

    <cleanup-policy-details :virtual-registries-setting-enabled="enabled" class="gl-mt-5" />
  </settings-section>
</template>

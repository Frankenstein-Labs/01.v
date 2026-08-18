<script>
import { GlAlert, GlLink, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SettingsSubSection from '~/vue_shared/components/settings/settings_sub_section.vue';
import getDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/queries/get_dependency_proxy_packages_settings.query.graphql';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';

export default {
  name: 'DependencyProxyPackagesSettings',
  components: {
    DependencyProxyPackagesSettingsForm,
    GlAlert,
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    SettingsSubSection,
  },
  deprecationHelpPath: helpPagePath('update/deprecations', {
    anchor: 'dependency-proxy-for-packages-is-deprecated',
  }),
  inject: {
    projectPath: {
      default: '',
    },
  },
  apollo: {
    dependencyProxyPackagesSettings: {
      query: getDependencyProxyPackagesSettings,
      context: {
        batchKey: 'PackageRegistryProjectSettings',
      },
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project?.dependencyProxyPackagesSetting || {},
      error(e) {
        this.fetchSettingsError = e;
        Sentry.captureException(e);
      },
    },
  },
  data() {
    return {
      dependencyProxyPackagesSettings: {},
      fetchSettingsError: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.dependencyProxyPackagesSettings.loading;
    },
  },
};
</script>

<template>
  <settings-sub-section
    :heading="s__('DependencyProxy|Dependency Proxy')"
    :description="
      s__(
        'DependencyProxy|Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
      )
    "
    data-testid="dependency-proxy-settings"
  >
    <gl-alert
      variant="warning"
      :dismissible="false"
      :title="s__('DependencyProxy|Dependency Proxy for Packages is deprecated')"
      class="gl-mb-4"
      data-testid="deprecation-alert"
    >
      <gl-sprintf
        :message="
          s__(
            'DependencyProxy|This feature will be removed in GitLab 20.0. We recommend migrating to the Maven Virtual Registry, which provides the same caching functionality with additional features. %{linkStart}Learn more about the deprecation%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.deprecationHelpPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <gl-alert
      v-if="fetchSettingsError"
      variant="warning"
      :dismissible="false"
      data-testid="fetch-error-alert"
    >
      {{
        s__('DependencyProxy|Something went wrong while fetching the dependency proxy settings.')
      }}
    </gl-alert>

    <gl-skeleton-loader v-else-if="isLoading" />
    <dependency-proxy-packages-settings-form v-else :data="dependencyProxyPackagesSettings" />
  </settings-sub-section>
</template>

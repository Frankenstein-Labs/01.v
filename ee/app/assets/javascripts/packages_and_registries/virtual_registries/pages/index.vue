<script>
import {
  GlIcon,
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlEmptyState,
  GlExperimentBadge,
  GlLink,
  GlSkeletonLoader,
  GlSprintf,
} from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-package-md.svg?url';
import mavenLogoUrl from '@gitlab/svgs/dist/illustrations/logos/maven.svg?url';
import dockerLogoUrl from '@gitlab/svgs/dist/illustrations/logos/docker.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import getVirtualRegistriesCountsQuery from '../graphql/queries/get_virtual_registries_counts.query.graphql';
import MavenI18n from './maven/i18n';
import ContainerI18n from './container/i18n';

const REGISTRY_TYPE_LOGOS = {
  maven: mavenLogoUrl,
  container: dockerLogoUrl,
};

const REGISTRY_TYPE_NAMES = {
  maven: MavenI18n.registryType,
  container: ContainerI18n.registryType,
};

export default {
  name: 'VirtualRegistriesApp',
  components: {
    CrudComponent,
    GlAlert,
    GlIcon,
    GlButton,
    GlCollapsibleListbox,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlEmptyState,
    GlExperimentBadge,
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    PageHeading,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['fullPath', 'registryTypes'],
  apollo: {
    registryCounts: {
      query: getVirtualRegistriesCountsQuery,
      variables() {
        return {
          groupPath: this.fullPath,
          includeMaven: 'maven' in this.registryTypes,
          includeContainer: 'container' in this.registryTypes,
        };
      },
      update(data) {
        return {
          maven: data.group?.mavenRegistries?.count ?? 0,
          container: data.group?.containerRegistries?.count ?? 0,
        };
      },
      error(error) {
        this.hasError = true;
        captureException({ component: this.$options.name, error });
      },
    },
  },
  data() {
    return {
      selectedRegistryType: Object.keys(this.registryTypes)[0],
      registryCounts: null,
      hasError: false,
    };
  },
  computed: {
    hasRegistryWithCount() {
      if (!this.registryCounts) return false;
      return Object.entries(this.registryCounts).some(
        ([key, count]) => this.registryTypes[key] && count > 0,
      );
    },
    registryTypesList() {
      return Object.entries(this.registryTypes).map(([key, data]) => ({
        key,
        ...data,
      }));
    },
    availableRegistryTypesList() {
      return this.registryTypesList.filter((item) => !this.isMaxReached(item.key));
    },
    canCreateVirtualRegistry() {
      return this.glAbilities.createVirtualRegistry;
    },
    createRegistryItems() {
      return this.registryTypesList.map((registry) => ({
        value: registry.key,
        text: this.getName(registry.key),
      }));
    },
    selectedRegistryNewPath() {
      return this.registryTypes[this.selectedRegistryType]?.newPagePath;
    },
    isMaxReachedForAllRegistryTypes() {
      return this.registryTypesList.every((registryType) => this.isMaxReached(registryType.key));
    },
  },
  methods: {
    getName(registryKey) {
      return REGISTRY_TYPE_NAMES[registryKey];
    },
    getImagePath(registryKey) {
      return REGISTRY_TYPE_LOGOS[registryKey];
    },
    isMaxReached(registryType) {
      const count = this.registryCounts?.[registryType] || 0;
      const maxCount = this.registryTypes[registryType]?.maxRegistriesCount || 0;
      return count === maxCount;
    },
    getDropdownItemAttrs(registryType) {
      return {
        text: this.getName(registryType.key),
        href: this.registryTypes[registryType.key].newPagePath,
      };
    },
    shouldShowMaxReachedForRegistry(registryKey) {
      return (
        this.canCreateVirtualRegistry &&
        !this.isMaxReachedForAllRegistryTypes &&
        this.isMaxReached(registryKey)
      );
    },
  },
  learnMorePath: helpPagePath('user/packages/virtual_registry/_index.md'),
  emptyStateIllustrationUrl,
};
</script>

<template>
  <div>
    <gl-skeleton-loader
      v-if="$apollo.queries.registryCounts.loading"
      :lines="3"
      class="gl-mt-4"
      :width="500"
    />
    <gl-alert v-else-if="hasError" variant="danger" :dismissible="false">
      {{
        s__(
          'VirtualRegistry|An error occurred while fetching virtual registries. Please try again.',
        )
      }}
    </gl-alert>
    <template v-else-if="hasRegistryWithCount">
      <page-heading>
        <template #heading>
          <span class="gl-flex gl-items-center gl-gap-3">
            <span>
              {{ s__('VirtualRegistry|Virtual registry') }}
            </span>
            <span class="gl-leading-20">
              <gl-experiment-badge type="beta" class="!gl-mx-0" />
            </span>
          </span>
        </template>
      </page-heading>
      <crud-component :title="s__('VirtualRegistry|Registry types')" class="gl-mt-5">
        <template v-if="canCreateVirtualRegistry" #actions>
          <span v-if="isMaxReachedForAllRegistryTypes" class="gl-text-right">{{
            s__('VirtualRegistry|Maximum number of registries reached.')
          }}</span>
          <gl-disclosure-dropdown
            v-else
            variant="confirm"
            placement="bottom-end"
            :toggle-text="s__('VirtualRegistry|Create registry')"
          >
            <gl-disclosure-dropdown-item
              v-for="registryType in availableRegistryTypesList"
              :key="registryType.key"
              :item="getDropdownItemAttrs(registryType)"
            >
              <template #list-item>
                <span class="gl-flex gl-items-center gl-gap-3">
                  <img
                    :src="getImagePath(registryType.key)"
                    width="18"
                    height="18"
                    aria-hidden="true"
                    class="gl-bg-transparent dark:gl-rounded-base dark:gl-bg-gray-900"
                  />
                  <span>{{ getName(registryType.key) }}</span></span
                ></template
              >
            </gl-disclosure-dropdown-item>
          </gl-disclosure-dropdown>
        </template>
        <ul class="content-list">
          <li
            v-for="registry in registryTypesList"
            :key="registry.key"
            class="!gl-flex gl-items-center !gl-py-4"
          >
            <div class="gl-flex gl-grow gl-items-center gl-gap-4">
              <img
                :src="getImagePath(registry.key)"
                width="32"
                height="32"
                class="gl-rounded-base gl-bg-transparent dark:gl-bg-gray-900"
                aria-hidden="true"
              />
              <div class="gl-flex gl-flex-col gl-gap-3 @sm/panel:gl-flex-row @sm/panel:!gl-gap-4">
                <span class="gl-font-bold">{{ getName(registry.key) }}</span>
                <gl-button
                  variant="link"
                  :href="registry.landingPagePath"
                  data-testid="view-registries-link"
                >
                  {{ s__('VirtualRegistry|View registries') }}
                </gl-button>
              </div>
            </div>
            <span v-if="shouldShowMaxReachedForRegistry(registry.key)" class="gl-text-right">{{
              s__('VirtualRegistry|Maximum number of registries reached.')
            }}</span>
          </li>
        </ul>
      </crud-component>
    </template>
    <gl-empty-state
      v-else
      :header-level="1"
      :svg-path="$options.emptyStateIllustrationUrl"
      :title="s__('VirtualRegistry|Get started with virtual registries')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'VirtualRegistry|Manage packages across multiple sources and streamline development workflows. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.learnMorePath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template v-if="canCreateVirtualRegistry" #actions>
        <div class="gl-flex gl-gap-3">
          <gl-collapsible-listbox
            v-model="selectedRegistryType"
            :toggle-text="getName(selectedRegistryType)"
            :items="createRegistryItems"
            is-check-centered
          >
            <template #toggle="{ accessibilityAttributes: { id, ...accessibilityAttributes } }">
              <gl-button
                class="!gl-min-w-26"
                button-text-classes="gl-flex gl-items-center gl-gap-3 gl-w-full"
                v-bind="accessibilityAttributes"
              >
                <img
                  :src="getImagePath(selectedRegistryType)"
                  width="32"
                  height="22"
                  aria-hidden="true"
                  class="gl-bg-transparent dark:gl-rounded-base dark:gl-bg-gray-900"
                />
                <span :id="id" class="gl-grow gl-text-left">
                  {{ getName(selectedRegistryType) }}
                </span>
                <gl-icon name="chevron-down" class="gl-button-icon gl-new-dropdown-chevron" />
              </gl-button>
            </template>
            <template #list-item="{ item }">
              <div class="gl-flex gl-items-center gl-gap-3">
                <img
                  :src="getImagePath(item.value)"
                  width="32"
                  height="22"
                  aria-hidden="true"
                  class="gl-bg-transparent dark:gl-rounded-base dark:gl-bg-gray-900"
                />
                <span data-testid="registry-name">{{ item.text }}</span>
              </div>
            </template>
          </gl-collapsible-listbox>
          <gl-button
            variant="confirm"
            :href="selectedRegistryNewPath"
            data-testid="create-registry-button"
          >
            {{ s__('VirtualRegistry|Create registry') }}
          </gl-button>
        </div>
      </template>
    </gl-empty-state>
  </div>
</template>

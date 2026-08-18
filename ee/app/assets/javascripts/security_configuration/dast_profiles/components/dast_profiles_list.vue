<script>
import {
  GlAlert,
  GlButton,
  GlModal,
  GlSkeletonLoader,
  GlTable,
  GlTooltipDirective,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { visitUrl } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { DAST_EDIT_ACTION, DAST_DELETE_ACTION } from '../constants';

export default {
  name: 'DastProfilesList',
  DAST_EDIT_ACTION,
  DAST_DELETE_ACTION,
  components: {
    GlAlert,
    GlButton,
    GlModal,
    GlSkeletonLoader,
    GlTable,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    SafeHtml,
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glSlotsMixin],
  props: {
    profiles: {
      type: Array,
      required: true,
    },
    tableLabel: {
      type: String,
      required: true,
    },
    fields: {
      type: Array,
      required: true,
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
    errorDetails: {
      type: Array,
      required: false,
      default: () => [],
    },
    noProfilesMessage: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    profilesPerPage: {
      type: Number,
      required: true,
    },
    hasMoreProfilesToLoad: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['delete-profile', 'load-more-profiles'],
  data() {
    return {
      toBeDeletedProfileId: null,
    };
  },
  computed: {
    hasError() {
      return this.errorMessage !== '';
    },
    hasErrorDetails() {
      return this.errorDetails.length > 0;
    },
    hasProfiles() {
      return this.profiles.length > 0;
    },
    isLoadingInitialProfiles() {
      return this.isLoading && !this.hasProfiles;
    },
    shouldShowTable() {
      return this.isLoadingInitialProfiles || this.hasProfiles || this.hasError;
    },
    modalId() {
      return `dast-profiles-list-${uniqueId()}`;
    },
    tableFields() {
      const defaultClasses = ['gl-break-all'];
      const defaultThClasses = ['!gl-bg-transparent', 'gl-text-default'];

      const dataFields = this.fields.map(({ key, label }) => ({
        key,
        label,
        class: defaultClasses,
        thClass: defaultThClasses,
      }));

      const staticFields = [{ key: 'actions', label: '', thClass: defaultThClasses }];

      return [...dataFields, ...staticFields];
    },
  },
  methods: {
    deleteTitle(item) {
      return this.isPolicyProfile(item)
        ? s__('DastProfiles|This profile is currently being used in a policy.')
        : s__('DastProfiles|Delete profile');
    },
    handleDelete() {
      this.$emit('delete-profile', this.toBeDeletedProfileId);
    },
    isPolicyProfile(item) {
      return Boolean(item?.referencedInSecurityPolicies?.length);
    },
    prepareProfileDeletion(profileId) {
      this.toBeDeletedProfileId = profileId;
      this.$refs[this.modalId].show();
    },
    handleCancel() {
      this.toBeDeletedProfileId = null;
    },
    navigateToProfile({ editPath }) {
      return visitUrl(editPath);
    },
    deleteActionVariant(item) {
      return this.isPolicyProfile(item) ? '' : 'danger';
    },
    cssDeleteActionClasses(item) {
      return this.isPolicyProfile(item) ? 'disabled !gl-cursor-default' : '';
    },
    actionDisclosureItemsConfig(item) {
      return {
        [DAST_EDIT_ACTION]: {
          text: __('Edit'),
          href: item.editPath,
          extraAttrs: {
            'data-testid': 'dast-edit-action',
            title: s__('DastProfiles|Edit profile'),
          },
        },
        [DAST_DELETE_ACTION]: {
          text: __('Delete'),
          action: () => this.prepareProfileDeletion(item.id),
          variant: this.deleteActionVariant(item),
          extraAttrs: {
            class: this.cssDeleteActionClasses(item),
            disabled: this.isPolicyProfile(item),
            ariaDisabled: this.isPolicyProfile(item),
            title: this.deleteTitle(item),
          },
        },
      };
    },
  },
};
</script>
<template>
  <section>
    <div v-if="shouldShowTable" class="gl-mt-6">
      <gl-table
        :aria-label="tableLabel"
        :busy="isLoadingInitialProfiles"
        :fields="tableFields"
        :items="profiles"
        stacked="md"
        fixed
        hover
        thead-class="gl-border-b-solid gl-border-default gl-border-1 !gl-pt-3"
        tbody-tr-class="hover:gl-cursor-pointer hover:!gl-bg-blue-50"
        @row-clicked="navigateToProfile"
      >
        <template v-if="hasError" #top-row>
          <td :colspan="tableFields.length">
            <gl-alert class="gl-my-4" variant="danger" :dismissible="false">
              {{ errorMessage }}
              <ul
                v-if="hasErrorDetails"
                :aria-label="s__('DastProfiles|Error Details')"
                class="gl-m-0 gl-p-0"
              >
                <li
                  v-for="errorDetail in errorDetails"
                  :key="errorDetail"
                  v-safe-html="errorDetail"
                ></li>
              </ul>
            </gl-alert>
          </td>
        </template>

        <template #cell(profileName)="{ value }">
          <div class="gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap">
            {{ value }}
          </div>
        </template>

        <template v-for="slotName in Object.keys(glSlots())" #[slotName]="slotScope">
          <slot :name="slotName" v-bind="slotScope"></slot>
        </template>

        <template #cell(actions)="{ item }">
          <div class="gl-text-right">
            <slot name="actions" :profile="item"></slot>

            <gl-disclosure-dropdown
              v-gl-tooltip
              class="gl-hidden @md/panel:!gl-inline-flex"
              toggle-class="!gl-border-0 !gl-shadow-none"
              text-sr-only
              :toggle-text="__('More actions')"
              :title="__('More actions')"
              no-caret
              category="tertiary"
              icon="ellipsis_v"
              placement="bottom-end"
              size="small"
            >
              <gl-disclosure-dropdown-item
                v-if="item.editPath"
                :item="actionDisclosureItemsConfig(item)[$options.DAST_EDIT_ACTION]"
              />
              <gl-disclosure-dropdown-item
                v-gl-tooltip="{
                  boundary: 'viewport',
                  placement: 'bottom',
                  disabled: !isPolicyProfile(item),
                }"
                :item="actionDisclosureItemsConfig(item)[$options.DAST_DELETE_ACTION]"
              />
            </gl-disclosure-dropdown>

            <gl-button
              v-if="item.editPath"
              :href="item.editPath"
              category="tertiary"
              class="gl-my-1 gl-ml-3 @md/panel:gl-hidden"
              size="small"
            >
              {{ __('Edit') }}
            </gl-button>
            <span
              v-gl-tooltip.hover.focus
              :title="deleteTitle(item)"
              data-testid="dast-profile-delete-tooltip"
            >
              <gl-button
                category="tertiary"
                icon="remove"
                variant="danger"
                size="small"
                class="gl-mx-3 gl-my-1 @md/panel:gl-hidden"
                data-testid="dast-profile-delete-button"
                :disabled="isPolicyProfile(item)"
                :aria-disabled="isPolicyProfile(item)"
                :aria-label="s__('DastProfiles|Delete profile')"
                @click="prepareProfileDeletion(item.id)"
              />
            </span>
          </div>
        </template>

        <template #table-busy>
          <div v-for="i in profilesPerPage" :key="i" data-testid="loadingIndicator">
            <gl-skeleton-loader :width="1248" :height="52">
              <rect x="0" y="16" width="300" height="20" rx="4" />
              <rect x="380" y="16" width="300" height="20" rx="4" />
              <rect x="770" y="16" width="300" height="20" rx="4" />
              <rect x="1140" y="11" width="50" height="30" rx="4" />
            </gl-skeleton-loader>
          </div>
        </template>
      </gl-table>

      <p v-if="hasMoreProfilesToLoad" class="gl-flex gl-justify-center">
        <gl-button
          data-testid="loadMore"
          :loading="isLoading && !hasError"
          @click="$emit('load-more-profiles')"
        >
          {{ __('Load more') }}
        </gl-button>
      </p>
    </div>

    <p v-else class="gl-my-4">
      {{ noProfilesMessage }}
    </p>

    <gl-modal
      :ref="modalId"
      :modal-id="modalId"
      :title="s__('DastProfiles|Are you sure you want to delete this profile?')"
      :ok-title="__('Delete')"
      :static="true"
      :lazy="true"
      ok-variant="danger"
      body-class="gl-hidden"
      @ok="handleDelete"
      @cancel="handleCancel"
    />

    <slot></slot>
  </section>
</template>

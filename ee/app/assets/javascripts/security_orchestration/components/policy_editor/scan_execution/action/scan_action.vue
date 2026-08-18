<script>
import { isEmpty } from 'lodash-es';
import { GlCollapsibleListbox, GlSprintf, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import { isProject, isGroup, isScanningReport } from 'ee/security_orchestration/components/utils';
import SectionLayout from '../../section_layout.vue';
import { ACTION_AND_LABEL } from '../../constants';
import {
  DEFAULT_SCANNER,
  SCAN_EXECUTION_SCANNERS,
  SCANNER_HUMANIZED_TEMPLATE,
  SCANNER_HUMANIZED_TEMPLATE_ALT,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
} from '../constants';
import { buildScannerAction } from '../lib';
import { CI_VARIABLE, FILTERS, TEMPLATE, SCAN_SETTINGS } from './scan_filters/constants';
import CiVariablesSelectors from './scan_filters/ci_variables_selectors.vue';
import TemplateSelector from './scan_filters/template_selector.vue';
import GroupDastProfileSelector from './scan_filters/group_dast_profile_selector.vue';
import ProjectDastProfileSelector from './scan_filters/project_dast_profile_selector.vue';
import RunnerTagsFilter from './scan_filters/runner_tags_filter.vue';
import ScanSettingsToggle from './scan_filters/scan_settings_toggle.vue';

export default {
  name: 'ScanAction',
  ACTION_AND_LABEL,
  CI_VARIABLE,
  FILTERS,
  VARIABLE_FILTER: FILTERS[0].value,
  TEMPLATE,
  SCAN_SETTINGS,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlSprintf,
    SectionLayout,
    CiVariablesSelectors,
    ProjectDastProfileSelector,
    GroupDastProfileSelector,
    RunnerTagsFilter,
    ScanSettingsToggle,
    TemplateSelector,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    initAction: {
      type: Object,
      required: true,
    },
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['changed', 'parsing-error', 'remove'],
  data() {
    const hasVariables = !isEmpty(this.initAction.variables);

    return {
      filters: {
        [CI_VARIABLE]: hasVariables,
      },
      selectedScanner: this.initAction.scan || DEFAULT_SCANNER,
    };
  },
  computed: {
    filtersDisabled() {
      return Boolean(this.filters[FILTERS[0].value]);
    },
    actionScannerList() {
      return Object.entries(SCAN_EXECUTION_SCANNERS).map(([value, text]) => ({
        value,
        text,
      }));
    },
    ciVariables() {
      return this.initAction.variables || {};
    },
    isCIVariableSelectorSelected() {
      return (
        this.isFilterSelected(this.$options.CI_VARIABLE) || Object.keys(this.ciVariables).length > 0
      );
    },
    isDast() {
      return this.selectedScanner === REPORT_TYPE_DAST;
    },
    selectedScannerText() {
      return SCAN_EXECUTION_SCANNERS[this.selectedScanner];
    },
    isFirstAction() {
      return this.actionIndex === 0;
    },
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    siteProfile() {
      return this.initAction.site_profile?.trim() ?? '';
    },
    scannerProfile() {
      return this.initAction.scanner_profile?.trim() ?? '';
    },
    tags() {
      return this.initAction.tags || [];
    },
    ignoreDefaultBeforeAfterScript() {
      return Boolean(this.initAction.scan_settings?.ignore_default_before_after_script);
    },
    scannerHumanizedMessage() {
      return isScanningReport(this.selectedScanner)
        ? SCANNER_HUMANIZED_TEMPLATE_ALT
        : SCANNER_HUMANIZED_TEMPLATE;
    },
  },
  watch: {
    initAction(action) {
      const hasVariables = !isEmpty(action.variables);
      this.filters = {
        ...this.filters,
        [CI_VARIABLE]: hasVariables,
      };
    },
  },
  methods: {
    isFilterSelected(filter) {
      return this.filters[filter];
    },
    emitFilterChanges(filter) {
      const updatedAction = { ...this.initAction };
      if (filter === CI_VARIABLE) delete updatedAction.variables;
      if (filter === TEMPLATE) delete updatedAction.template;
      this.$emit('changed', updatedAction);
    },
    removeFilter(filter) {
      const newFilters = { ...this.filters };
      delete newFilters[filter];
      this.filters = newFilters;
      this.emitFilterChanges(filter);
    },
    removeYamlProperty(property) {
      const updatedAction = { ...this.initAction };
      delete updatedAction[property];
      this.$emit('changed', updatedAction);
    },
    removeScanSettings() {
      this.removeYamlProperty('scan_settings');
    },
    selectFilter(filter) {
      this.filters = {
        ...this.filters,
        [filter]: true,
      };

      if (filter === CI_VARIABLE) {
        this.triggerChanged({ variables: { '': '' } });
      }
    },
    setSelectedScanner({
      scanner = this.selectedScanner,
      siteProfile = this.siteProfile,
      scannerProfile = this.scannerProfile,
    }) {
      const updatedAction = buildScannerAction({
        scanner,
        siteProfile,
        scannerProfile,
        id: this.initAction.id,
      });

      const { tags, variables } = this.initAction;

      if (tags) {
        updatedAction.tags = [...tags];
      }

      if (scanner !== this.selectedScanner) {
        this.selectedScanner = scanner;
        this.filters = {};
      } else if (!isEmpty(variables)) {
        updatedAction.variables = { ...variables };
      }

      this.$emit('changed', updatedAction);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initAction, ...value });
    },
  },
  i18n: {
    scannersHeaderText: s__('ScanExecutionPolicy|Select a scanner'),
    addVariableButtonText: s__('ScanExecutionPolicy|Add new CI variables'),
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-mb-4 gl-ml-5 gl-text-subtle"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>
    <div class="gl-flex gl-w-full">
      <div class="gl-flex-1">
        <section-layout class="gl-pb-0 gl-pr-0" :show-remove-button="false">
          <template #content>
            <section-layout class="gl-w-full gl-bg-default" :show-remove-button="false">
              <template #content>
                <gl-sprintf :message="scannerHumanizedMessage">
                  <template #scan>
                    <gl-collapsible-listbox
                      data-testid="scan-type-selector"
                      :items="actionScannerList"
                      :header-text="$options.i18n.scannersHeaderText"
                      :selected="selectedScanner"
                      :toggle-text="selectedScannerText"
                      @select="setSelectedScanner({ scanner: $event })"
                    />
                  </template>
                </gl-sprintf>
              </template>
            </section-layout>
          </template>
        </section-layout>
        <section-layout class="gl-pr-0 gl-pt-3" :show-remove-button="false">
          <template #content>
            <project-dast-profile-selector
              v-if="isProject && isDast"
              :full-path="namespacePath"
              :saved-scanner-profile-name="scannerProfile"
              :saved-site-profile-name="siteProfile"
              @error="
                $emit('parsing-error', $options.POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY)
              "
              @profiles-selected="setSelectedScanner"
            />

            <group-dast-profile-selector
              v-if="isGroup && isDast"
              :saved-scanner-profile-name="scannerProfile"
              :saved-site-profile-name="siteProfile"
              @set-profile="setSelectedScanner"
            />

            <runner-tags-filter
              :selected="tags"
              @remove="removeYamlProperty('tags')"
              @input="triggerChanged"
              @error="$emit('parsing-error', $options.POLICY_ACTION_BUILDER_TAGS_ERROR_KEY)"
            />

            <template-selector
              :selected="initAction.template"
              :scan-type="selectedScanner"
              @input="triggerChanged"
              @remove="removeFilter($options.TEMPLATE)"
            />

            <ci-variables-selectors
              v-if="isCIVariableSelectorSelected"
              :scan-type="initAction.scan"
              :selected="initAction.variables"
              :action-index="actionIndex"
              :error-sources="errorSources"
              @input="triggerChanged"
              @remove="removeFilter($options.CI_VARIABLE)"
            />

            <gl-button
              v-if="!filtersDisabled"
              class="gl-ml-4 gl-mt-4"
              data-testid="add-variable-button"
              :aria-label="$options.i18n.addVariableButtonText"
              variant="link"
              @click="selectFilter($options.VARIABLE_FILTER)"
            >
              {{ $options.i18n.addVariableButtonText }}
            </gl-button>

            <scan-settings-toggle
              :selected="ignoreDefaultBeforeAfterScript"
              @input="triggerChanged"
              @remove="removeScanSettings"
            />
          </template>
        </section-layout>
      </div>

      <div class="security-policies-bg-subtle gl-p-3">
        <gl-button
          icon="remove"
          category="tertiary"
          :aria-label="__('Remove')"
          data-testid="remove-action"
          @click="$emit('remove')"
        />
      </div>
    </div>
  </div>
</template>

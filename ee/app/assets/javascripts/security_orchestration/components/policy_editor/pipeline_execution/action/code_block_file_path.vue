<script>
import {
  GlAlert,
  GlFormGroup,
  GlFormInputGroup,
  GlIcon,
  GlInputGroupText,
  GlLink,
  GlSprintf,
  GlFormInput,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { editProjectPath } from '~/lib/utils/path_helpers/project';
import { BV_SHOW_TOOLTIP, BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { DEPRECATED_INJECT, INJECT, OVERRIDE, SCHEDULE, SUFFIX_ON_CONFLICT } from '../constants';
import SuffixSelector from '../suffix_selector.vue';
import { validateStrategyValues } from './utils';
import CodeBlockStrategySelector from './code_block_strategy_selector.vue';

export default {
  i18n: {
    filePathInputCopy: s__('ScanExecutionPolicy|%{labelStart}File path:%{labelEnd} %{filePath}'),
    pipelineFilePathCopy: {
      [DEPRECATED_INJECT]: s__(
        'ScanExecutionPolicy|%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      ),
      [INJECT]: s__(
        'ScanExecutionPolicy|%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      ),
      [OVERRIDE]: s__(
        'ScanExecutionPolicy|%{strategySelector}the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      ),
      [SCHEDULE]: s__(
        'ScanExecutionPolicy|%{strategySelector} pipeline file to run from %{projectSelector}',
      ),
    },
    filePathPrependLabel: __('No project selected'),
    fileRefLabel: s__('ScanExecutionPolicy|Select ref'),
    fileRefCopy: s__('ScanExecutionPolicy|File reference (Optional) %{refSelector}'),
    filePathInputPlaceholder: s__('ScanExecutionPolicy|Link existing CI file'),
    filePathInputEmptyMessage: s__("ScanExecutionPolicy|The file path can't be empty"),
    filePathInputDoesNotExistMessage: s__(
      "ScanExecutionPolicy|The file at that project, ref, and path doesn't exist",
    ),
    formGroupLabel: s__('ScanExecutionPolicy|file path group'),
    selectedProjectInformation: {
      [INJECT]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      ),
      [DEPRECATED_INJECT]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. Custom stages used in the pipeline execution YAML are ignored, unless they are defined in the `.gitlab-ci.yml` file of the target project. All GitLab CI/CD features are supported.',
      ),
      [OVERRIDE]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file overrides the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      ),
      [SCHEDULE]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file of the target project is run at the scheduled time. All GitLab CI/CD features are supported.',
      ),
    },
    tooltipText: s__('ScanExecutionPolicy|Select project first, and then insert a file path'),
    scheduleAccessAlertTitle: s__(
      'ScanExecutionPolicy|Verify the file in the selected project is accessible',
    ),
    scheduleAccessAlertMessage: s__(
      "ScanExecutionPolicy|For this schedule to run, %{project} needs to allow this project access to its configuration files, with an allowed file pattern that matches the file path. Check with whoever owns that project's settings, or modify the %{linkStart}settings%{linkEnd} directly.",
    ),
    scheduleAccessAlertMessageNoProject: s__(
      "ScanExecutionPolicy|For this schedule to run, the selected project needs to allow this project access to its configuration files, with an allowed file pattern that matches the file path. Check with whoever owns that project's settings, or modify the settings directly.",
    ),
    scheduleAccessAlertLink: __('Learn more.'),
  },
  SCHEDULE_ACCESS_SETTING_HELP_PATH: helpPagePath(
    'user/application_security/policies/scheduled_pipeline_execution_policies',
    { anchor: 'enable-access-to-cicd-configuration-files' },
  ),
  refSelectorTranslations: {
    noRefSelected: __('default branch'),
  },
  SELECTED_PROJECT_TOOLTIP: 'selected-project-tooltip',
  name: 'CodeBlockFilePath',
  components: {
    CodeBlockStrategySelector,
    GlAlert,
    GlIcon,
    GlLink,
    GlFormGroup,
    GlFormInputGroup,
    GlFormInput,
    GlInputGroupText,
    GlSprintf,
    GlTruncate,
    GroupProjectsDropdown,
    RefSelector,
    SuffixSelector,
  },
  directives: { GlTooltip: GlTooltipDirective },
  inject: ['namespacePath', 'rootNamespacePath', 'namespaceType'],
  props: {
    strategy: {
      type: String,
      required: true,
      validator: validateStrategyValues,
    },
    filePath: {
      type: String,
      required: false,
      default: null,
    },
    doesFileExist: {
      type: Boolean,
      required: false,
      default: true,
    },
    selectedRef: {
      type: String,
      required: false,
      default: '',
    },
    selectedProject: {
      type: Object,
      required: false,
      default: null,
    },
    suffix: {
      type: String,
      required: false,
      default: SUFFIX_ON_CONFLICT,
    },
  },
  emits: ['select-project', 'select-ref', 'select-strategy', 'update-file-path', 'update-suffix'],
  data() {
    return {
      dirty: false,
    };
  },
  computed: {
    fileBlockMessage() {
      return this.$options.i18n.pipelineFilePathCopy[this.strategy];
    },
    isValidFilePath() {
      if (this.filePath === null) {
        return null;
      }

      return Boolean(this.filePath);
    },
    projectAndRefState() {
      return !this.isValidFilePath || this.doesFileExist;
    },
    filePathState() {
      if (this.isValidFilePath) {
        return this.doesFileExist;
      }
      return !this.dirty;
    },
    filePathValidationError() {
      if (!this.isValidFilePath) {
        return this.$options.i18n.filePathInputEmptyMessage;
      }

      if (!this.doesFileExist) {
        return this.$options.i18n.filePathInputDoesNotExistMessage;
      }

      return '';
    },
    selectedProjectId() {
      return this.selectedProject?.id;
    },
    selectedProjectIdShortFormat() {
      const value = getIdFromGraphQLId(this.selectedProjectId);
      return value ? value.toString() : '';
    },
    selectedProjectFullPath() {
      return this.selectedProject?.fullPath || this.$options.i18n.filePathPrependLabel;
    },
    selectedProjectTooltip() {
      return this.selectedProject?.fullPath || this.$options.i18n.tooltipText;
    },
    groupProjectsPath() {
      return isGroup(this.namespaceType) ? this.namespacePath : this.rootNamespacePath;
    },
    selectedProjectInformationText() {
      return this.$options.i18n.selectedProjectInformation[this.strategy];
    },
    showScheduleAccessAlert() {
      return this.strategy === SCHEDULE;
    },
    scheduleAccessAlertMessage() {
      return this.selectedProject?.fullPath
        ? this.$options.i18n.scheduleAccessAlertMessage
        : this.$options.i18n.scheduleAccessAlertMessageNoProject;
    },
    selectedProjectSettingsPath() {
      if (!this.selectedProject?.fullPath) {
        return null;
      }

      return editProjectPath(this.selectedProject.fullPath, { anchor: 'js-shared-permissions' });
    },
  },
  methods: {
    updatedFilePath(value) {
      this.dirty = true;
      this.$emit('update-file-path', value);
    },
    setStrategy(strategy) {
      this.$emit('select-strategy', strategy);
    },

    setSelectedProject(project) {
      this.$emit('select-project', project);
    },
    setSelectedRef(ref) {
      this.$emit('select-ref', ref);
    },
    updateSuffix(suffix) {
      this.$emit('update-suffix', suffix);
    },
    triggerTooltip(state) {
      const EVENT = state ? BV_SHOW_TOOLTIP : BV_HIDE_TOOLTIP;
      this.$root.$emit(EVENT, this.$options.SELECTED_PROJECT_TOOLTIP);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-3">
    <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="fileBlockMessage">
        <template #strategySelector>
          <code-block-strategy-selector :strategy="strategy" @select="setStrategy" />
        </template>

        <template #bold="{ content }">
          <b>{{ content }}</b>
        </template>

        <template #projectSelector>
          <group-projects-dropdown
            class="gl-max-w-20"
            data-testid="pipeline-execution-project-dropdown"
            :group-full-path="groupProjectsPath"
            :selected="selectedProjectId"
            :multiple="false"
            :state="projectAndRefState"
            @select="setSelectedProject"
          />
          <gl-icon
            v-if="selectedProjectInformationText"
            v-gl-tooltip
            name="information-o"
            :title="selectedProjectInformationText"
          />
        </template>

        <template #refSelector>
          <ref-selector
            v-if="selectedProjectId"
            class="gl-max-w-20"
            :project-id="selectedProjectIdShortFormat"
            :state="projectAndRefState"
            :translations="$options.refSelectorTranslations"
            :value="selectedRef"
            @input="setSelectedRef"
          />

          <gl-form-input
            v-else
            class="gl-w-auto"
            :placeholder="$options.i18n.fileRefLabel"
            :state="projectAndRefState"
            :value="selectedRef"
            @input="setSelectedRef"
          />
        </template>
      </gl-sprintf>
    </div>

    <div class="gl-flex gl-w-full gl-flex-nowrap gl-items-baseline gl-gap-3">
      <gl-sprintf :message="$options.i18n.filePathInputCopy">
        <template #label="{ content }">
          <span class="gl-whitespace-nowrap">{{ content }}</span>
        </template>

        <template #filePath>
          <gl-form-group
            class="gl-mb-0 gl-w-full"
            label-sr-only
            data-testid="ci-file-path-text"
            :label="$options.i18n.formGroupLabel"
            :optional="false"
            :invalid-feedback="filePathValidationError"
            :state="filePathState"
          >
            <gl-form-input-group
              id="file-path"
              :placeholder="$options.i18n.filePathInputPlaceholder"
              :state="filePathState"
              :disabled="!selectedProjectId"
              :value="filePath"
              @mouseenter="triggerTooltip(true)"
              @mouseleave="triggerTooltip(false)"
              @input="updatedFilePath"
            >
              <template #prepend>
                <gl-input-group-text
                  v-gl-tooltip="{
                    id: $options.SELECTED_PROJECT_TOOLTIP,
                    title: selectedProjectTooltip,
                  }"
                  :class="{ 'gl-border-default': !selectedProjectId }"
                  class="!gl-max-h-full gl-max-w-26"
                >
                  <gl-truncate :text="selectedProjectFullPath" position="start" />
                </gl-input-group-text>
              </template>
            </gl-form-input-group>
          </gl-form-group>
        </template>
      </gl-sprintf>
    </div>

    <div
      data-testid="pipeline-execution-ref-selector"
      class="gl-flex gl-w-full gl-flex-nowrap gl-items-baseline gl-gap-3"
    >
      <gl-sprintf :message="$options.i18n.fileRefCopy">
        <template #refSelector>
          <ref-selector
            v-if="selectedProjectId"
            class="gl-max-w-20"
            :project-id="selectedProjectIdShortFormat"
            :state="projectAndRefState"
            :translations="$options.refSelectorTranslations"
            :value="selectedRef"
            @input="setSelectedRef"
          />

          <gl-form-input
            v-else
            class="gl-w-auto"
            :placeholder="$options.i18n.fileRefLabel"
            :state="projectAndRefState"
            :value="selectedRef"
            @input="setSelectedRef"
          />
        </template>
      </gl-sprintf>
    </div>

    <suffix-selector :suffix="suffix" @update="updateSuffix" />

    <gl-alert
      v-if="showScheduleAccessAlert"
      data-testid="schedule-access-setting-alert"
      variant="info"
      :dismissible="false"
      :title="$options.i18n.scheduleAccessAlertTitle"
    >
      <gl-sprintf :message="scheduleAccessAlertMessage">
        <template #project>
          <strong>{{ selectedProject.fullPath }}</strong>
        </template>
        <template #link="{ content }">
          <gl-link
            data-testid="schedule-access-settings-link"
            :href="selectedProjectSettingsPath"
            target="_blank"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
      <gl-link
        data-testid="schedule-access-docs-link"
        :href="$options.SCHEDULE_ACCESS_SETTING_HELP_PATH"
        target="_blank"
        >{{ $options.i18n.scheduleAccessAlertLink }}</gl-link
      >
    </gl-alert>
  </div>
</template>

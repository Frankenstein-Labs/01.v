<script>
import { parseCustomFileConfiguration } from 'ee/security_orchestration/components/policy_editor/utils';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';
import {
  SCHEDULE,
  SUFFIX_ON_CONFLICT,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import CodeBlockFilePath from './code_block_file_path.vue';
import VariablesOverrideList from './variables_override_list.vue';

export default {
  name: 'PipelineExecutionActionSection',
  components: {
    CodeBlockFilePath,
    VariablesOverrideList,
  },
  props: {
    action: {
      type: Object,
      required: true,
    },
    doesFileExist: {
      type: Boolean,
      required: false,
      default: true,
    },
    strategy: {
      type: String,
      required: true,
    },
    suffix: {
      type: String,
      required: false,
      default: SUFFIX_ON_CONFLICT,
    },
    variablesOverride: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  emits: ['changed', 'update-strategy'],
  data() {
    return {
      selectedProject: undefined,
    };
  },
  computed: {
    ciConfigurationPath() {
      return this.action?.include?.[0] || {};
    },
    filePath() {
      return this.ciConfigurationPath.file;
    },
    selectedRef() {
      return this.ciConfigurationPath.ref;
    },
    isScheduledPolicy() {
      return this.strategy === SCHEDULE;
    },
  },
  async mounted() {
    const { project: selectedProject } = parseCustomFileConfiguration(this.action.include?.[0]);

    if (selectedProject && selectedProject.fullPath) {
      selectedProject.id = await this.getProjectId(selectedProject.fullPath);
      this.selectedProject = selectedProject;
    }
  },
  methods: {
    async getProjectId(fullPath) {
      try {
        const { data } = await this.$apollo.query({
          query: getProjectId,
          variables: {
            fullPath,
          },
        });

        return data?.project?.id || '';
      } catch (e) {
        return '';
      }
    },
    setStrategy(strategy) {
      this.$emit('update-strategy', strategy);
    },
    setSelectedRef(ref) {
      this.setCiConfigurationPath({ ...this.ciConfigurationPath, ref });
    },
    setSelectedProject(project) {
      this.selectedProject = null;
      this.$nextTick(() => {
        this.selectedProject = project;

        const config = { ...this.ciConfigurationPath };

        if ('ref' in config) delete config.ref;

        if (project) {
          config.project = project?.fullPath;
        } else {
          delete config.project;
        }

        this.setCiConfigurationPath({ ...config });
      });
    },
    updatedFilePath(path) {
      const { file, ...configuration } = this.ciConfigurationPath;

      this.setCiConfigurationPath({ ...configuration, ...(path ? { file: path } : {}) });
    },
    setCiConfigurationPath(pathConfig) {
      this.updateProperty('content', { include: [pathConfig] });
    },
    updateProperty(property, value) {
      this.$emit('changed', property, value);
    },
  },
};
</script>

<template>
  <div>
    <code-block-file-path
      :file-path="filePath"
      :strategy="strategy"
      :selected-ref="selectedRef"
      :selected-project="selectedProject"
      :does-file-exist="doesFileExist"
      :suffix="suffix"
      @select-strategy="setStrategy"
      @select-ref="setSelectedRef"
      @select-project="setSelectedProject"
      @update-file-path="updatedFilePath"
      @update-suffix="updateProperty('suffix', $event)"
    />

    <variables-override-list
      v-if="!isScheduledPolicy"
      class="gl-mt-4"
      :variables-override="variablesOverride"
      @select="updateProperty('variables_override', $event)"
    />
  </div>
</template>

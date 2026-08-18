<script>
import { GlCollapsibleListbox, GlSprintf, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import getDotDevfileYamlQuery from '../graphql/queries/get_dot_devfile_yaml.query.graphql';
import getDotDevfileFolderQuery from '../graphql/queries/get_dot_devfile_folder.query.graphql';
import {
  USER_ROOT_DEVFILE_PATH,
  USER_DEVFILE_FOLDER_PATH,
  DEFAULT_DEVFILE_OPTION,
} from '../constants';

export const i18n = {
  queryFailureMessage: s__(
    'Workspaces|Failed to fetch custom devfiles. %{linkStart}Reload to try again%{linkEnd}.',
  ),
};

export default {
  name: 'DevfileListbox',
  components: {
    GlCollapsibleListbox,
    GlSprintf,
    GlButton,
  },
  props: {
    value: {
      type: String,
      required: false,
      default: '',
    },
    projectPath: {
      type: String,
      required: true,
    },
    devfileRef: {
      type: String,
      required: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      selectedDevfilePath: this.value,
      userDevfilePathsWithGroup: {
        text: s__('Workspaces|From your code'),
        options: [],
      },
      defaultDevfilePathWithGroup: {
        text: __('Default'),
        options: [
          { text: s__('Workspaces|Use GitLab default devfile'), value: DEFAULT_DEVFILE_OPTION },
        ],
      },
      isDevfileQueryLoading: false,
      isDevfileQueryFailed: false,
      infiniteScrollLoading: false,
      endCursor: null,
      hasNextPage: false,
      infiniteScrollEnabled: true,
    };
  },
  computed: {
    devfilePathsWithGroup() {
      if (this.userDevfilePathsWithGroup.options.length === 0) {
        return [this.defaultDevfilePathWithGroup];
      }
      return [this.defaultDevfilePathWithGroup, this.userDevfilePathsWithGroup];
    },
    userRootDevfilePaths() {
      return USER_ROOT_DEVFILE_PATH;
    },
    userDevfileFolderPath() {
      return USER_DEVFILE_FOLDER_PATH;
    },
    listboxAttrs() {
      return {
        ...this.$attrs,
        ...(this.isDevfileQueryFailed
          ? { variant: 'danger', category: 'secondary', icon: 'warning' }
          : {}),
      };
    },
    toggleText() {
      if (this.isDevfileQueryLoading) {
        return ' ';
      }
      return '';
    },
  },
  watch: {
    value(newValue) {
      this.selectedDevfilePath = newValue;
    },
    selectedDevfilePath(newValue) {
      this.$emit('input', newValue);
    },
    projectPath: {
      handler: 'getDevfiles',
      immediate: true,
    },
    devfileRef: {
      handler: 'getDevfiles',
      immediate: true,
    },
  },
  async mounted() {
    await this.getDevfiles();
  },
  methods: {
    resetDevfileVariables() {
      this.selectedDevfilePath = null;
      this.userDevfilePathsWithGroup.options = [];
      this.endCursor = null;
      this.hasNextPage = false;
      this.isDevfileQueryFailed = false;
    },
    async getRootDevfiles() {
      if (this.isDevfileQueryFailed) return;

      try {
        const { data: yamlData } = await this.$apollo.query({
          query: getDotDevfileYamlQuery,
          variables: {
            projectPath: this.projectPath,
            filePath: this.userRootDevfilePaths,
            ref: this.devfileRef,
          },
          fetchPolicy: 'no-cache',
        });

        const userRootYamlDevfiles = (
          yamlData?.project?.repository?.blobs?.nodes?.map((node) => node.path) || []
        ).filter((element) => this.userRootDevfilePaths.includes(element));
        userRootYamlDevfiles.forEach((file) => {
          this.userDevfilePathsWithGroup.options.push({
            text: file,
            value: file,
          });
        });
      } catch {
        this.isDevfileQueryFailed = true;
      }
    },
    async onBottomReached() {
      if (this.infiniteScrollLoading || this.isDevfileQueryFailed || !this.hasNextPage) return;

      this.infiniteScrollLoading = true;

      await this.getFolderDevfiles();

      this.infiniteScrollLoading = false;
    },
    async getFolderDevfiles() {
      if (this.isDevfileQueryFailed) return;

      try {
        const { data: folderData } = await this.$apollo.query({
          query: getDotDevfileFolderQuery,
          variables: {
            projectPath: this.projectPath,
            path: this.userDevfileFolderPath,
            ref: this.devfileRef,
            nextPageCursor: this.endCursor,
          },
          fetchPolicy: 'no-cache',
        });

        const blobs = folderData?.project?.repository?.tree?.blobs;
        if (blobs) {
          blobs.edges
            .filter((n) => n.node.path.endsWith('.yaml') || n.node.path.endsWith('.yml'))
            .map((n) => n.node.path)
            .forEach((file) => {
              this.userDevfilePathsWithGroup.options.push({
                text: file,
                value: file,
              });
            });
          this.hasNextPage = blobs.pageInfo?.hasNextPage;
          this.endCursor = blobs.pageInfo?.endCursor;
        }
      } catch {
        this.isDevfileQueryFailed = true;
      }
    },
    async getDevfiles() {
      if (this.isDevfileQueryLoading) return;

      this.isDevfileQueryLoading = true;
      this.resetDevfileVariables();

      await this.getRootDevfiles();
      await this.getFolderDevfiles();

      if (this.isDevfileQueryFailed) {
        this.userDevfilePathsWithGroup.options = [];
      }

      this.selectedDevfilePath =
        this.userDevfilePathsWithGroup.options.length > 0
          ? this.userDevfilePathsWithGroup.options[0].value
          : DEFAULT_DEVFILE_OPTION;

      this.isDevfileQueryLoading = false;
    },
  },
  i18n,
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      v-model="selectedDevfilePath"
      :items="devfilePathsWithGroup"
      header-text="Devfile"
      :loading="isDevfileQueryLoading"
      :infinite-scroll="infiniteScrollEnabled"
      :infinite-scroll-loading="infiniteScrollLoading"
      :toggle-text="toggleText"
      v-bind="listboxAttrs"
      @bottom-reached="onBottomReached"
    />
    <div class="gl-mt-3 gl-text-feedback-danger">
      <gl-sprintf v-if="isDevfileQueryFailed" :message="$options.i18n.queryFailureMessage">
        <template #link="{ content }">
          <gl-button variant="link" @click="getDevfiles">{{ content }}</gl-button>
        </template>
      </gl-sprintf>
    </div>
  </div>
</template>

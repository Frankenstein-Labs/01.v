<script>
import { uniqueId } from 'lodash-es';
import { GlIcon, GlLink, GlButton, GlCollapse, GlBadge, GlPopover, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { toNounSeriesText } from '~/lib/utils/grammar';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import codeOwnersInfoQuery from '../../../graphql_shared/queries/code_owners_info.query.graphql';

export const i18n = {
  title: s__('CodeOwners|Code owners'),
  and: __('and'),
  errorMessage: s__('CodeOwners|An error occurred while loading code owners.'),
  manageBranchRules: __('Manage branch rules'),
  noCodeOwnersText: s__(
    'CodeOwners|Assign users and groups as approvers for specific file changes.',
  ),
  helpText: s__(
    'CodeOwners|Code owners are users and groups that can approve specific file changes.',
  ),
  learnMore: s__('CodeOwners|Learn more.'),
  showAll: s__('CodeOwners|Show all'),
  hideAll: s__('CodeOwners|Hide all'),
};

export const codeOwnersHelpPath = helpPagePath('user/project/codeowners/_index.md');

export default {
  name: 'CodeOwners',
  i18n,
  codeOwnersHelpPath,
  helpPopoverId: uniqueId('help-popover-'),
  components: {
    GlIcon,
    GlLink,
    GlButton,
    GlBadge,
    GlCollapse,
    GlPopover,
    GlSprintf,
    HelpIcon,
  },
  apollo: {
    project: {
      query: codeOwnersInfoQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          filePath: this.filePath,
          ref: this.branch,
        };
      },
      skip() {
        return !this.filePath;
      },
      error() {
        createAlert({ message: this.$options.i18n.errorMessage });
      },
    },
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: false,
      default: '',
    },
    branch: {
      type: String,
      required: false,
      default: '',
    },
    canViewBranchRules: {
      type: Boolean,
      required: false,
      default: false,
    },
    branchRulesPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      isCodeOwnersExpanded: false,
      project: {},
    };
  },
  computed: {
    blobInfo() {
      return this.project?.repository?.blobs?.nodes[0];
    },
    collapseIcon() {
      return this.isCodeOwnersExpanded ? 'chevron-down' : 'chevron-right';
    },
    codeOwnersPath() {
      return this.project?.repository?.codeOwnersPath;
    },
    codeOwners() {
      return this.blobInfo?.codeOwners || [];
    },
    codeOwnersTotal() {
      return this.blobInfo?.codeOwners?.length;
    },
    toggleText() {
      return this.isCodeOwnersExpanded ? this.$options.i18n.hideAll : this.$options.i18n.showAll;
    },
    hasCodeOwners() {
      return this.filePath && Boolean(this.codeOwners.length);
    },
    codeOwnersSprintfMessage() {
      return toNounSeriesText(
        this.codeOwners.map((codeOwner, index) => `%{linkStart}${index}%{linkEnd}`),
      );
    },
    isLoading() {
      return this.$apollo.queries.project.loading;
    },
  },
  watch: {
    filePath() {
      this.$apollo.queries.project.refetch();
    },
  },
  methods: {
    toggleCodeOwners() {
      this.isCodeOwnersExpanded = !this.isCodeOwnersExpanded;
    },
    getCodeOwner(idx) {
      // what: idx could be a str coming from sprintf so we transform it to a number
      return this.codeOwners[Number(idx)];
    },
  },
};
</script>

<template>
  <div
    v-if="filePath"
    class="well-segment blob-auxiliary-viewer file-owner-content gl-border-t gl-flex gl-items-baseline gl-justify-between gl-border-t-section"
    data-testid="codeowners-container"
  >
    <div class="gl-flex gl-flex-wrap gl-pr-3">
      <div>
        <gl-icon name="users" />
        <component
          :is="hasCodeOwners ? 'gl-link' : 'span'"
          class="gl-font-bold !gl-text-default"
          :href="codeOwnersPath"
          data-testid="codeowners-file-link"
          >{{ $options.i18n.title }}
        </component>
      </div>
      <div v-if="!hasCodeOwners && !isLoading" class="gl-ml-3">
        <span data-testid="no-codeowners-text">{{ $options.i18n.noCodeOwnersText }}</span>
        <gl-link
          data-testid="codeowners-docs-link"
          target="_blank"
          :href="$options.codeOwnersHelpPath"
          >{{ $options.i18n.learnMore }}</gl-link
        >
      </div>

      <template v-if="hasCodeOwners && !isLoading">
        <gl-badge class="gl-mx-3 gl-self-center">{{ codeOwnersTotal }}</gl-badge>
        <gl-button
          variant="link"
          size="small"
          data-testid="collapse-toggle"
          class="gl-mr-3"
          :icon="collapseIcon"
          @click="toggleCodeOwners"
        >
          {{ toggleText }}
        </gl-button>
        <gl-collapse :visible="isCodeOwnersExpanded" data-testid="code-owners-list">
          <gl-sprintf :message="codeOwnersSprintfMessage">
            <template #link="{ content }">
              <gl-link :href="getCodeOwner(content).webPath" target="_blank">{{
                getCodeOwner(content).name
              }}</gl-link>
            </template>
          </gl-sprintf>
        </gl-collapse>
      </template>
    </div>

    <div
      v-if="canViewBranchRules || hasCodeOwners"
      data-testid="code-owners-actions"
      class="gl-flex gl-shrink-0 gl-items-baseline gl-gap-3"
    >
      <help-icon
        v-if="hasCodeOwners"
        :id="$options.helpPopoverId"
        :aria-label="$options.i18n.helpText"
        class="gl-self-center"
        data-testid="help-popover-trigger"
      />
      <gl-popover
        v-if="hasCodeOwners"
        :target="$options.helpPopoverId"
        placement="top"
        triggers="hover focus"
      >
        {{ $options.i18n.helpText }}
        <gl-link :href="$options.codeOwnersHelpPath">
          {{ $options.i18n.learnMore }}
        </gl-link>
      </gl-popover>

      <gl-button
        v-if="canViewBranchRules"
        size="small"
        :href="branchRulesPath"
        data-testid="branch-rules-link"
      >
        {{ $options.i18n.manageBranchRules }}
      </gl-button>
    </div>
  </div>
</template>

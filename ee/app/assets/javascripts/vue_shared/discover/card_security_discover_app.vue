<script>
import { GlButton, GlTooltipDirective, GlSprintf, GlLink, GlModalDirective } from '@gitlab/ui';
import { DISCOVER_PLANS_MORE_INFO_LINK } from 'jh_else_ee/vue_shared/discover/constants';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import securityDependencyImageUrl from 'ee_images/promotions/security-dependencies.png';
import MovePersonalProjectToGroupModal from 'ee/projects/components/move_personal_project_to_group_modal.vue';
import { MOVE_PERSONAL_PROJECT_TO_GROUP_MODAL } from 'ee/projects/constants';

export default {
  name: 'CardSecurityDiscoverApp',
  DISCOVER_PLANS_MORE_INFO_LINK,
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModalDirective,
  },
  components: {
    GlButton,
    GlSprintf,
    GlLink,
    MovePersonalProjectToGroupModal,
  },
  mixins: [Tracking.mixin()],
  props: {
    project: {
      type: Object,
      required: false,
      default: null,
    },
    linkMain: {
      type: String,
      required: false,
      default: '',
    },
    linkSecondary: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    discoverButtonProps() {
      return {
        class: 'gl-ml-3',
        variant: 'confirm',
        // False positive i18n lint: https://gitlab.com/gitlab-org/frontend/eslint-plugin-i18n/issues/26
        // eslint-disable-next-line @gitlab/require-i18n-strings
        rel: 'noopener noreferrer',
        'data-track-action': 'click_button',
        'data-track-property': 0,
      };
    },
    upgradeButtonProps() {
      return {
        category: 'secondary',
        'data-testid': 'discover-button-upgrade',
        'data-track-label': 'security-discover-upgrade-cta',

        ...this.discoverButtonProps,
      };
    },
    trialButtonProps() {
      return {
        category: 'primary',
        'data-testid': 'discover-button-trial',
        'data-track-label': 'security-discover-trial-cta',
        ...this.discoverButtonProps,
      };
    },
    isPersonalProject() {
      return this.project.isPersonal;
    },
  },
  i18n: {
    discoverTitle: s__(
      'Discover|Security capabilities, integrated into your development lifecycle',
    ),
    discoverImageAltText: s__("Discover|An example of GitLab's Dependency list feature"),
    discoverUpgradeLabel: s__('Discover|Upgrade now'),
    discoverTrialLabel: s__('Discover|Start a free trial'),
    captions: [
      s__(
        'Discover|Check your application for security vulnerabilities that may lead to unauthorized access, data leaks, and denial of services.',
      ),
      s__(
        'Discover|GitLab will perform static and dynamic tests on the code of your application, looking for known flaws and report them in the merge request so you can fix them before merging.',
      ),
      s__(
        "Discover|For code that's already live in production, our dashboards give you an easy way to prioritize any issues that are found, empowering your team to ship quickly and securely.",
      ),
    ],
    discoverPlanCaption: s__(
      'Discover|See the other features of the %{linkStart}Ultimate plan%{linkEnd}.',
    ),
  },
  modalId: MOVE_PERSONAL_PROJECT_TO_GROUP_MODAL,
  securityDependencyImageUrl,
};
</script>

<template>
  <div class="discover-box">
    <h2 class="gl-mx-auto gl-my-8 gl-text-center gl-text-heading">
      {{ $options.i18n.discoverTitle }}
    </h2>
    <div class="gl-text-center">
      <img
        :src="$options.securityDependencyImageUrl"
        class="gl-mb-8 gl-max-w-full"
        :alt="$options.i18n.discoverImageAltText"
      />
      <p v-for="caption in $options.i18n.captions" :key="caption">
        {{ caption }}
      </p>
      <div class="gl-mx-auto gl-my-0">
        <p class="gl-mb-9 gl-text-center gl-text-default">
          <gl-sprintf :message="$options.i18n.discoverPlanCaption">
            <template #link="{ content }">
              <gl-link :href="$options.DISCOVER_PLANS_MORE_INFO_LINK" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </div>
    </div>
    <div class="gl-mx-auto gl-flex gl-flex-row gl-justify-center">
      <template v-if="isPersonalProject">
        <gl-button v-gl-modal-directive="$options.modalId" v-bind="upgradeButtonProps">
          {{ $options.i18n.discoverUpgradeLabel }}
        </gl-button>

        <gl-button v-gl-modal-directive="$options.modalId" v-bind="trialButtonProps">
          {{ $options.i18n.discoverTrialLabel }}
        </gl-button>

        <move-personal-project-to-group-modal :project-name="project.name" />
      </template>

      <template v-else>
        <gl-button v-bind="upgradeButtonProps" :href="linkSecondary">
          {{ $options.i18n.discoverUpgradeLabel }}
        </gl-button>

        <gl-button v-bind="trialButtonProps" :href="linkMain">
          {{ $options.i18n.discoverTrialLabel }}
        </gl-button>
      </template>
    </div>
  </div>
</template>

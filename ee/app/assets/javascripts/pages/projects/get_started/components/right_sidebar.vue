<script>
import { GlIcon, GlButton, GlCard, GlLink } from '@gitlab/ui';
import { __ } from '~/locale';
import GitlabUniversityDuoChatImgURL from 'ee_images/learn_gitlab/gitlab_university_duo_chat.png';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'RightSidebar',
  components: {
    GlIcon,
    GlButton,
    GlCard,
    GlLink,
  },
  mixins: [InternalEvents.mixin()],
  methods: {
    trackLearnMoreClick(label) {
      this.trackEvent('click_learn_more_links_in_get_started', { label });
    },
    trackEnrollClick() {
      this.trackEvent('click_enroll_gitlab_university_in_get_started');
    },
  },
  GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK:
    'https://university.gitlab.com/courses/10-best-practices-for-using-duo-chat',
  LEARN_MORE_LINKS: [
    {
      text: __('Git'),
      url: helpPagePath('topics/git/get_started'),
      trackingLabel: 'git',
    },
    {
      text: __('Managing code'),
      url: helpPagePath('user/get_started/get_started_managing_code'),
      trackingLabel: 'managing_code',
    },
    {
      text: __('GitLab Duo'),
      url: helpPagePath('user/get_started/getting_started_gitlab_duo'),
      trackingLabel: 'gitlab_duo',
    },
    {
      text: __('Organize work with projects'),
      url: helpPagePath('user/get_started/get_started_projects'),
      trackingLabel: 'organize_work_with_projects',
    },
    {
      text: __('GitLab CI/CD'),
      url: helpPagePath('ci/_index.md'),
      trackingLabel: 'gitlab_ci_cd',
    },
    {
      text: __('SSH keys'),
      url: helpPagePath('user/ssh'),
      trackingLabel: 'ssh_keys',
    },
  ],
  GitlabUniversityDuoChatImgURL,
};
</script>

<template>
  <div>
    <h2 class="gl-text-size-h2">{{ s__('LearnGitLab|GitLab University') }}</h2>
    <gl-card class="gl-overflow-hidden gl-rounded-lg" header-class="gl-p-0" body-class="gl-p-3">
      <template #header>
        <img :src="$options.GitlabUniversityDuoChatImgURL" class="gl-w-full" aria-hidden="true" />
      </template>
      <template #default>
        <h3 class="gl-m-0 gl-text-base">
          {{ s__('LearnGitLab|10 best practices for using GitLab Duo') }}
        </h3>
        <p class="gl-my-3">
          {{
            s__(
              'LearnGitLab|In this tutorial, we explore 10 tips and best practices to integrate GitLab Duo Chat into your AI-native DevSecOps workflows and refine your prompts for the best results.',
            )
          }}
        </p>
        <gl-button
          :href="$options.GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK"
          data-testid="gitlab-university-enroll-link"
          category="primary"
          @click="trackEnrollClick"
        >
          {{ s__('LearnGitLab|Enroll') }}
          <gl-icon name="external-link" />
        </gl-button>
      </template>
    </gl-card>
    <h2 class="gl-mb-3 gl-mt-7 gl-text-size-h2">{{ s__('LearnGitLab|Learn more') }}</h2>
    <ul class="gl-list-none gl-p-0">
      <li v-for="link in $options.LEARN_MORE_LINKS" :key="link.url" class="gl-mb-3">
        <gl-link
          :href="link.url"
          :data-testid="`${link.trackingLabel}-learn-more-link`"
          @click="trackLearnMoreClick(link.trackingLabel)"
          >{{ link.text }}</gl-link
        >
      </li>
    </ul>
  </div>
</template>

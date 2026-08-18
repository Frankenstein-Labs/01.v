<script>
import { GlButton, GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import EmptyTodosAllDoneSvg from '@gitlab/svgs/dist/illustrations/empty-todos-all-done-md.svg';
import {
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
} from 'ee/compliance_dashboard/constants';
import { s__ } from '~/locale';

export default {
  name: 'NewFrameworkSuccess',
  components: {
    GlButton,
    GlCard,
    GlSprintf,
    GlLink,
  },
  inject: ['groupSecurityPoliciesPath'],
  methods: {
    navigateToEditFramework() {
      this.$router.push({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: this.$route.query.id },
      });
    },
    navigateToComplianceCenter() {
      this.$router.push({
        name: ROUTE_FRAMEWORKS,
        query: { id: this.$route.query.id },
      });
    },
    navigateToProjectsReport() {
      this.$router.push({ name: ROUTE_PROJECTS });
    },
  },

  i18n: {
    illustrationAlt: s__('NewFramework|All todos done.'),
    title: s__('NewFramework|Compliance framework created!'),
    text: s__(
      'NewFramework|Use the compliance framework to scope policies and include projects to make sure they are compliant.',
    ),
    editFramework: s__('ComplianceFrameworksReport|Edit framework'),
    backtoComplianceCenter: s__('NewFramework|Back to compliance center'),
    subTitle: s__('NewFramework|Suggested next steps'),
    policies: s__('NewFramework|Scope policies'),
    whyPoliciesTitle: s__('NewFramework|Why scope policies?'),
    whyPoliciesText: s__(
      'NewFramework|Policies scoped to a framework serve as solutions to specific compliance requirements and are applied to projects.',
    ),
    howPoliciesTitle: s__('NewFramework|How to scope policies?'),
    howPoliciesText: s__(
      'NewFramework|Go to the %{linkStart}policy management page%{linkEnd} to scope a policy for this framework.',
    ),
    projects: s__('NewFramework|Apply to projects'),
    whyProjectsTitle: s__('NewFramework|Why apply the framework to projects?'),
    whyProjectsText: s__(
      'NewFramework|Projects that have this framework applied are automatically checked against requirements and have policies enforced.',
    ),
    howProjectsTitle: s__('NewFramework|How do I apply the framework to projects?'),
    howProjectsText: s__(
      'NewFramework|Go to the %{linkStart}compliance center%{linkEnd} to apply this framework to projects.',
    ),
  },
  EmptyTodosAllDoneSvg,
};
</script>

<template>
  <div class="gl-mt-12 gl-flex gl-flex-col gl-items-center">
    <img
      class="gl-dark-invert-keep-hue"
      :src="$options.EmptyTodosAllDoneSvg"
      :alt="$options.i18n.illustrationAlt"
    />
    <h1 class="gl-heading-1 gl-mt-6">{{ $options.i18n.title }}</h1>
    <p class="gl-text-lg">{{ $options.i18n.text }}</p>
    <section class="gl-mb-5">
      <gl-button variant="confirm" category="primary" @click="navigateToComplianceCenter">
        {{ $options.i18n.backtoComplianceCenter }}
      </gl-button>
      <gl-button variant="confirm" category="secondary" @click="navigateToEditFramework">
        {{ $options.i18n.editFramework }}
      </gl-button>
    </section>
    <h2 class="gl-heading-2 gl-mt-6">{{ $options.i18n.subTitle }}</h2>
    <gl-card
      data-testid="policies-card"
      class="gl-mb-6 @md/panel:gl-w-3/5"
      header-class="gl-bg-strong"
      body-class="gl-shadow-x0-y2-b4-s0"
    >
      <template #header>
        <h3 class="gl-heading-3 gl-mb-0">{{ $options.i18n.policies }}</h3>
      </template>
      <h4 class="gl-heading-4">{{ $options.i18n.whyPoliciesTitle }}</h4>
      <p>{{ $options.i18n.whyPoliciesText }}</p>
      <h4 class="gl-heading-4">{{ $options.i18n.howPoliciesTitle }}</h4>
      <gl-sprintf :message="$options.i18n.howPoliciesText">
        <template #link="{ content }">
          <gl-link :href="groupSecurityPoliciesPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-card>
    <gl-card
      data-testid="projects-card"
      class="@md/panel:gl-w-3/5"
      header-class="gl-bg-strong"
      body-class="gl-shadow-x0-y2-b4-s0"
    >
      <template #header>
        <h3 class="gl-heading-3 gl-mb-0">{{ $options.i18n.projects }}</h3>
      </template>
      <h4 class="gl-heading-4">{{ $options.i18n.whyProjectsTitle }}</h4>
      <p>{{ $options.i18n.whyProjectsText }}</p>
      <h4 class="gl-heading-4">{{ $options.i18n.howProjectsTitle }}</h4>
      <gl-sprintf :message="$options.i18n.howProjectsText">
        <template #link="{ content }">
          <gl-link @click="navigateToProjectsReport">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-card>
  </div>
</template>

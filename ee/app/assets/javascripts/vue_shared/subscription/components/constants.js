import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL } from '~/constants';

export const DUO_CHAT_FEATURE_ID = 'duoChat';

const getNotInTrialSaasFeatures = () => {
  return [
    {
      id: 'dap',
      iconName: 'check',
      variant: 'info',
      title: s__('BillingPlans|GitLab Duo Agent Platform'),
    },
    {
      id: 'ciCd',
      iconName: 'check',
      variant: 'info',
      title: s__('BillingPlans|Advanced CI/CD'),
    },
    {
      id: 'noCreditCard',
      iconName: 'check',
      variant: 'info',
      title: s__('BillingPlans|No credit card required'),
    },
  ];
};

const notInTrialSaasHeader = s__('BillingPlans|Get the most out of GitLab with Ultimate');

const notInTrialSaasSubheader = s__(
  'BillingPlans|Start an Ultimate trial to try the complete set of features from GitLab.',
);

const getDuoChatFeature = ({
  usePurchaseCreditsCopy = false,
  purchaseCreditsUrl = '',
  hasMonthlyCreditCommitment = false,
  creditsGeneralizationUi = false,
} = {}) => {
  if (hasMonthlyCreditCommitment) {
    return {
      id: DUO_CHAT_FEATURE_ID,
      iconName: 'duo-chat',
      variant: 'default',
      title: 'GitLab Duo Agent Platform',
      description: s__(
        'BillingPlans|You will still have access to all GitLab Credits you have purchased',
      ),
      docsLink: helpPagePath('user/duo_agent_platform/_index'),
      hideButton: true,
    };
  }

  if (usePurchaseCreditsCopy) {
    return {
      id: DUO_CHAT_FEATURE_ID,
      iconName: 'duo-chat',
      variant: 'default',
      title: 'GitLab Duo Agent Platform',
      descriptionWithCreditsLink: s__(
        'BillingPlans|AI-powered features for writing code and automating workflows. Purchase %{creditsLinkStart}credits%{creditsLinkEnd} to unlock AI capabilities for your group, starting at $1 with volume discounts available.',
      ),
      docsLink: helpPagePath('user/duo_agent_platform/_index'),
      buttonText: creditsGeneralizationUi
        ? s__('BillingPlans|Learn more')
        : s__('BillingPlans|Purchase credits'),
      ...(creditsGeneralizationUi ? {} : { purchaseCreditsUrl }),
    };
  }

  return {
    id: DUO_CHAT_FEATURE_ID,
    iconName: 'duo-chat',
    variant: 'default',
    title: 'GitLab Duo Agent Platform',
    description: s__(
      'BillingPlans|AI agents and automated flows that work alongside you to answer complex questions, automate tasks, and streamline development. Use pre-built options or create custom agents and flows for your team. Powered by GitLab Credits.',
    ),
    descriptionWithoutCredits: s__(
      'BillingPlans|AI agents and automated flows that work alongside you to answer complex questions, automate tasks, and streamline development. Use pre-built options or create custom agents and flows for your team.',
    ),
    docsLink: helpPagePath('user/duo_agent_platform/_index'),
    buttonText: s__('BillingPlans|Learn more'),
  };
};

const getTrialActiveFeatures = [
  {
    id: 'epics',
    iconName: 'work-item-epic',
    variant: 'default',
    title: s__('BillingPlans|Epics'),
    description: s__(
      'BillingPlans|Track groups of related issues to manage large initiatives and monitor progress toward long-term goals.',
    ),
    docsLink: helpPagePath('/user/group/epics/_index.md'),
  },
  {
    id: 'repositoryPullMirroring',
    iconName: 'deployments',
    variant: 'default',
    title: s__('BillingPlans|Repository pull mirroring'),
    description: s__(
      'BillingPlans|Automatically sync branches, tags, and commits from an external repository with GitLab.',
    ),
    docsLink: helpPagePath('/user/project/repository/mirror/pull'),
  },
  {
    id: 'mergeTrains',
    iconName: 'merge',
    variant: 'default',
    title: s__('BillingPlans|Merge trains'),
    description: s__(
      'BillingPlans|Automatically merge changes in sequence to prevent conflicts and keep your branch stable.',
    ),
    docsLink: helpPagePath('/ci/pipelines/merge_trains'),
  },
  {
    id: 'escalationPolicies',
    iconName: 'shield',
    variant: 'default',
    title: s__('BillingPlans|Escalation policies'),
    description: s__(
      'BillingPlans|Automatically notify the next responder when critical alerts are unacknowledged and ensure no incident is missed.',
    ),
    docsLink: helpPagePath('/operations/incident_management/escalation_policies'),
  },
  {
    id: 'mergeRequestApprovals',
    iconName: 'approval',
    variant: 'default',
    title: s__('BillingPlans|Merge request approvals'),
    description: s__(
      'BillingPlans|Control who can approve merge requests to ensure code quality and compliance.',
    ),
    docsLink: helpPagePath('/user/project/merge_requests/approvals/settings'),
  },
];

export const getTrialActiveFeatureHighlights = ({
  usePurchaseCreditsCopy = false,
  purchaseCreditsUrl = '',
  hasMonthlyCreditCommitment = false,
  creditsGeneralizationUi = false,
} = {}) => ({
  header: s__('BillingPlans|Get the most from your trial'),
  subheader: s__('BillingPlans|Explore these Premium features to optimize your GitLab experience.'),
  features: [
    getDuoChatFeature({
      usePurchaseCreditsCopy,
      purchaseCreditsUrl,
      hasMonthlyCreditCommitment,
      creditsGeneralizationUi,
    }),
    ...getTrialActiveFeatures,
  ],
  ctaLabel: s__('BillingPlans|Choose Premium'),
});

export const FEATURE_HIGHLIGHTS = {
  trialExpired: {
    header: s__('BillingPlans|Level up with Premium'),
    subheader: s__(
      "BillingPlans|Upgrade and unlock advanced features that boost your team's productivity instantly.",
    ),
    features: [
      {
        id: 'aiChat',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Chat in the IDE'),
      },
      {
        id: 'aiCode',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Code Suggestions in the IDE'),
      },
      {
        id: 'ciCd',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Advanced CI/CD'),
      },
      {
        id: 'projectManagement',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Team Project Management'),
      },
    ],
    ctaLabel: s__('BillingPlans|Upgrade to Premium'),
  },
  notInTrialSaas: {
    header: notInTrialSaasHeader,
    subheader: notInTrialSaasSubheader,
    features: getNotInTrialSaasFeatures(),
    ctaLabel: s__('BillingPlans|Start free trial'),
  },
  notInTrialSM: {
    header: s__('BillingPlans|Get the most out of GitLab with Ultimate'),
    subheader: s__(
      'BillingPlans|Start an Ultimate trial to try the complete set of features from GitLab.',
    ),
    features: [
      {
        id: 'ciCd',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Advanced CI/CD'),
      },
      {
        id: 'mergeRequestApprovals',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Merge request approvals'),
      },
      {
        id: 'mergeTrains',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Merge trains'),
      },
      {
        id: 'additionalFeatures',
        iconName: 'plus',
        variant: 'info',
        title: s__('BillingPlans|Additional features'),
        showAsLink: true,
        docsLink: `${PROMO_URL}/pricing/feature-comparison/`,
        tracking: { 'data-event-tracking': 'click_sm_additional_features_subscription_page' },
      },
    ],
    ctaLabel: s__('BillingPlans|Start free trial'),
    secondaryCtaLabel: s__('BillingPlans|Explore plans'),
  },
};

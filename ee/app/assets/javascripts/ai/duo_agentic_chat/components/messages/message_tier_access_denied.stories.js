import MessageTierAccessDenied from './message_tier_access_denied.vue';

const baseMessage = {
  message_type: 'agent',
  role: 'assistant',
  message_sub_type: 'tier_access_denied',
  content:
    'Listing epics requires a **GitLab Premium** subscription (or higher).\n\n[Learn more](https://docs.gitlab.com/user/duo_agent_platform/)',
  required_plan: 'premium',
};

const renderWith =
  (provide) =>
  (_, { argTypes }) => ({
    components: { MessageTierAccessDenied },
    props: Object.keys(argTypes),
    provide,
    template:
      '<message-tier-access-denied :message="message" :is-hand-raise-lead-available="isHandRaiseLeadAvailable" />',
  });

const ownerProvide = {
  canBuyAddon: true,
  tierUpgradePath: '/-/subscriptions/upgrade_base_plan?namespace_id=42',
};
const freeAddonCreditsOwnerProvide = {
  canBuyAddon: true,
};
const nonOwnerProvide = { canBuyAddon: false };

export default {
  component: MessageTierAccessDenied,
  title: 'ee/ai/duo_agentic_chat/message_tier_access_denied',
};

export const Owner = renderWith(ownerProvide).bind({});
Owner.args = { message: baseMessage };

export const FreeAddonCreditsOwner = renderWith(freeAddonCreditsOwnerProvide).bind({});
FreeAddonCreditsOwner.args = { message: baseMessage, isHandRaiseLeadAvailable: true };

export const NonOwner = renderWith(nonOwnerProvide).bind({});
NonOwner.args = { message: baseMessage };

export const MissingRequiredPlan = renderWith(ownerProvide).bind({});
MissingRequiredPlan.args = {
  message: { ...baseMessage, required_plan: undefined },
};

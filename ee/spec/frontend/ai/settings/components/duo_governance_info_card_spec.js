import { GlButton, GlCard } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoGovernanceInfoCard from 'ee/ai/settings/components/duo_governance_info_card.vue';

describe('DuoGovernanceInfoCard', () => {
  let wrapper;

  const duoGovernancePath = '/groups/test/-/settings/gitlab_duo/governance';

  const createComponent = (injected = {}) => {
    wrapper = shallowMountExtended(DuoGovernanceInfoCard, {
      provide: {
        duoGovernancePath,
        ...injected,
      },
    });
  };

  const findCard = () => wrapper.findComponent(GlCard);
  const findHeader = () => wrapper.findByTestId('duo-governance-info-card-header');
  const findDescription = () => wrapper.findByTestId('duo-governance-info-card-description');
  const findActionButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders the card', () => {
    expect(findCard().exists()).toBe(true);
  });

  it('renders the header with correct text', () => {
    expect(findHeader().text()).toBe('Governance');
  });

  it('renders the description with correct text', () => {
    expect(findDescription().text()).toBe('Control how your AI-powered features are used.');
  });

  it('renders the action button with correct text', () => {
    expect(findActionButton().text()).toBe('Change governance');
  });

  it('renders the action button with the correct href', () => {
    expect(findActionButton().attributes('href')).toBe(duoGovernancePath);
  });
});

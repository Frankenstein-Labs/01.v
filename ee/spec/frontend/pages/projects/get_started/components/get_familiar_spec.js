import { GlCard, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GetFamiliar from 'ee/pages/projects/get_started/components/get_familiar.vue';

describe('Get Familiar component', () => {
  let wrapper;

  const createComponent = ({ glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(GetFamiliar, {
      provide: {
        glFeatures,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows Get Familiar with DAP heading', () => {
    expect(wrapper.find('h2').text()).toBe('Get familiar with GitLab Duo Agent Platform');
  });

  it('shows the correct description text', () => {
    expect(wrapper.find('p.gl-text-subtle').text()).toBe(
      'Explore these resources to learn essential features and best practices.',
    );
  });

  it('renders the GitLab Duo Agent Platform card', () => {
    const card = wrapper.findComponent(GlCard);
    expect(card.exists()).toBe(true);
    expect(card.attributes('data-testid')).toBe('duo-code-suggestions-card');
  });

  it('does not render card header', () => {
    const card = wrapper.findComponent(GlCard);
    expect(card.attributes('header-class')).toBeUndefined();
  });

  it('displays all four DAP feature list items', () => {
    const listItems = wrapper.findAll('ul li');
    expect(listItems).toHaveLength(4);

    expect(listItems.at(0).text()).toContain('GitLab Credits:');
    expect(listItems.at(1).text()).toContain('Agentic Chat:');
    expect(listItems.at(2).text()).toContain('Agents:');
    expect(listItems.at(3).text()).toContain('Flows:');
  });

  it('displays the features list with correct accessibility label', () => {
    const featuresList = wrapper.find('ul');
    expect(featuresList.attributes('aria-label')).toBe('GitLab Duo Agent Platform features');
  });

  it('renders GitLab Credits link', () => {
    const link = wrapper.findComponent(GlLink);
    expect(link.exists()).toBe(true);
    expect(link.text()).toBe('Learn about GitLab Credits');
    expect(link.attributes('target')).toBe('_blank');
  });

  it('does not render walkthrough button', () => {
    expect(wrapper.findByTestId('walkthrough-link').exists()).toBe(false);
  });
});

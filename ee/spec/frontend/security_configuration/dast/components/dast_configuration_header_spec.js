import { GlBadge, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DastConfigurationHeader from 'ee/security_configuration/dast/components/dast_configuration_header.vue';

describe('EE DAST Configuration Header', () => {
  let wrapper;
  const pipelineId = 'pipeline-id';
  const pipelinePath = 'pipeline-path';
  const pipelineCreatedAt = '2022-06-20T10:17:18Z';

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(DastConfigurationHeader, {
      propsData: {
        ...options,
      },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findLink = () => wrapper.findComponent(GlLink);
  const findHeaderText = () => wrapper.findByTestId('dast-header-text');

  it('renders header elements disabled', () => {
    const badgeLabel = 'Not enabled';
    const badgeText = 'No previous scans found for this project';

    createComponent();

    expect(findBadge().props('variant')).toBe('neutral');
    expect(findBadge().text()).toBe(badgeLabel);
    expect(findHeaderText().text()).toBe(badgeText);
    expect(findLink().exists()).toBe(false);
  });

  it('should show latest pipeline info if dast is disabled but used before', () => {
    const badgeLabel = 'Not enabled';
    const badgeText = 'Last scan triggered';

    createComponent({
      dastEnabled: false,
      pipelineId,
      pipelinePath,
      pipelineCreatedAt,
    });

    expect(findBadge().props('variant')).toBe('neutral');
    expect(findBadge().text()).toBe(badgeLabel);
    expect(findHeaderText().text()).toBe(`${badgeText} Jun 20, 2022 in pipeline`);
  });

  it('should be enabled if dast is enabled', () => {
    const dastEnabled = true;
    const badgeLabel = 'Enabled';

    createComponent({
      dastEnabled,
      pipelineId,
      pipelinePath,
      pipelineCreatedAt,
    });

    expect(findBadge().props('variant')).toBe('success');
    expect(findBadge().text()).toBe(badgeLabel);
    expect(findHeaderText().text()).toBe('Last scan triggered Jun 20, 2022 in pipeline');

    expect(findLink().exists()).toBe(true);
    expect(findLink().attributes('href')).toBe(pipelinePath);
  });
});

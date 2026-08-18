import { GlAlert, GlAccordion } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { DETAILS_ROUTE_NAME, SECRET_ROTATION_STATUS } from 'ee/ci/secrets/constants';
import SecretsAlertBanner from 'ee/ci/secrets/components/secrets_table/secrets_alert_banner.vue';

describe('SecretsAlertBanner component', () => {
  let wrapper;

  const mockSecretsToRotate = [
    {
      id: 'secret-1',
      name: 'SECRET_ONE',
      rotationInfo: {
        status: SECRET_ROTATION_STATUS.approaching,
      },
    },
    {
      id: 'secret-2',
      name: 'SECRET_TWO',
      rotationInfo: {
        status: SECRET_ROTATION_STATUS.approaching,
      },
    },
    {
      id: 'secret-3',
      name: 'SECRET_THREE',
      rotationInfo: {
        status: SECRET_ROTATION_STATUS.overdue,
      },
    },
    {
      id: 'secret-4',
      name: 'SECRET_FOUR',
      rotationInfo: {
        status: SECRET_ROTATION_STATUS.overdue,
      },
    },
  ];

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findAccordions = () => wrapper.findAllComponents(GlAccordion);
  const findSecretLinks = () => wrapper.findAllComponents(RouterLinkStub);

  const createComponent = (props = {}) => {
    wrapper = mountExtended(SecretsAlertBanner, {
      propsData: {
        secretsToRotate: mockSecretsToRotate,
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the alert with correct properties', () => {
    const alert = findAlert();

    expect(alert.props('title')).toBe('Some secrets require your attention');
    expect(alert.props('variant')).toBe('warning');
  });

  it('displays rotation messages with correct counts', () => {
    expect(wrapper.text()).toContain(
      '2 secrets need to be manually rotated soon to maintain security',
    );
    expect(wrapper.text()).toContain(
      '2 secrets have not been rotated after the configured rotation reminder intervals',
    );
  });

  it('renders accordions for secret details', () => {
    expect(findAccordions()).toHaveLength(2);
  });

  it('renders secret links with correct routes', () => {
    const secretLinks = findSecretLinks();

    expect(secretLinks).toHaveLength(4);
    expect(secretLinks.at(0).props('to')).toEqual({
      name: DETAILS_ROUTE_NAME,
      params: { secretName: 'SECRET_ONE' },
    });
    expect(secretLinks.at(1).props('to')).toEqual({
      name: DETAILS_ROUTE_NAME,
      params: { secretName: 'SECRET_TWO' },
    });
    expect(secretLinks.at(2).props('to')).toEqual({
      name: DETAILS_ROUTE_NAME,
      params: { secretName: 'SECRET_THREE' },
    });
    expect(secretLinks.at(3).props('to')).toEqual({
      name: DETAILS_ROUTE_NAME,
      params: { secretName: 'SECRET_FOUR' },
    });
  });
});

import { GlPopover, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteReplicationStatus from 'ee/geo_sites/components/details/secondary_site/geo_site_replication_status.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { REPLICATION_STATUS_UI, REPLICATION_PAUSE_URL } from 'ee/geo_sites/constants';
import { MOCK_SECONDARY_SITE } from 'ee_jest/geo_sites/mock_data';

describe('GeoSiteReplicationStatus', () => {
  let wrapper;

  const defaultProps = {
    site: MOCK_SECONDARY_SITE,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(GeoSiteReplicationStatus, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        HelpIcon,
      },
    });
  };

  const findReplicationStatusText = () => wrapper.findByTestId('replication-status-text');
  const findQuestionIcon = () => wrapper.findComponent(HelpIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findGlPopoverLink = () => findGlPopover().findComponent(GlLink);

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the replication status text', () => {
        expect(findReplicationStatusText().exists()).toBe(true);
      });

      it('renders the question icon correctly', () => {
        expect(findQuestionIcon().exists()).toBe(true);
        expect(findQuestionIcon().attributes('name')).toBe('question-o');
      });

      it('renders the GlPopover always', () => {
        expect(findGlPopover().exists()).toBe(true);
      });

      it('renders the popover link correctly', () => {
        expect(findGlPopoverLink().exists()).toBe(true);
        expect(findGlPopoverLink().attributes('href')).toBe(REPLICATION_PAUSE_URL);
      });
    });

    describe.each`
      enabled  | dbReplicationLagSeconds | uiData
      ${true}  | ${null}                 | ${REPLICATION_STATUS_UI.disabled}
      ${true}  | ${-1}                   | ${REPLICATION_STATUS_UI.enabled}
      ${true}  | ${0}                    | ${REPLICATION_STATUS_UI.enabled}
      ${true}  | ${12}                   | ${REPLICATION_STATUS_UI.enabled}
      ${false} | ${null}                 | ${REPLICATION_STATUS_UI.disabled}
      ${false} | ${-1}                   | ${REPLICATION_STATUS_UI.paused}
      ${false} | ${0}                    | ${REPLICATION_STATUS_UI.paused}
      ${false} | ${12}                   | ${REPLICATION_STATUS_UI.paused}
    `(`conditionally`, ({ enabled, dbReplicationLagSeconds, uiData }) => {
      beforeEach(() => {
        createComponent({ site: { enabled, dbReplicationLagSeconds } });
      });

      describe(`when enabled is ${enabled} and replication lag is ${dbReplicationLagSeconds}`, () => {
        it(`renders the replication status text correctly`, () => {
          expect(findReplicationStatusText().classes(uiData.color)).toBe(true);
          expect(findReplicationStatusText().text()).toBe(uiData.text);
        });
      });
    });
  });
});

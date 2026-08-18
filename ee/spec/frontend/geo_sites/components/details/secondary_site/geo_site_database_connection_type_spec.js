import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteDatabaseConnectionType from 'ee/geo_sites/components/details/secondary_site/geo_site_database_connection_type.vue';
import { DB_CONNECTION_TYPE_UI } from 'ee/geo_sites/constants';
import { MOCK_SECONDARY_SITE } from 'ee_jest/geo_sites/mock_data';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

describe('GeoSiteDatabaseConnectionType', () => {
  let wrapper;

  const defaultProps = {
    site: MOCK_SECONDARY_SITE,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(GeoSiteDatabaseConnectionType, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDatabaseConnectionTypeText = () =>
    wrapper.findByTestId('database-connection-type-text');
  const findHelpIcon = () => wrapper.findComponent(HelpIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the database connection type text', () => {
        expect(findDatabaseConnectionTypeText().exists()).toBe(true);
      });

      it('renders the question icon correctly', () => {
        expect(findHelpIcon().exists()).toBe(true);
      });

      it('renders the GlPopover always', () => {
        expect(findGlPopover().exists()).toBe(true);
        expect(findGlPopover().props().target()).toBe(findHelpIcon().element);
      });
    });

    describe.each`
      dbReplicationLagSeconds | uiData
      ${null}                 | ${DB_CONNECTION_TYPE_UI.direct}
      ${-1}                   | ${DB_CONNECTION_TYPE_UI.replicating}
      ${0}                    | ${DB_CONNECTION_TYPE_UI.replicating}
      ${12}                   | ${DB_CONNECTION_TYPE_UI.replicating}
    `(`conditionally`, ({ dbReplicationLagSeconds, uiData }) => {
      beforeEach(() => {
        createComponent({ site: { dbReplicationLagSeconds } });
      });

      describe(`when replication lag is ${dbReplicationLagSeconds}`, () => {
        it(`renders the db connection type text correctly`, () => {
          expect(findDatabaseConnectionTypeText().text()).toBe(uiData.text);
        });
      });
    });
  });
});

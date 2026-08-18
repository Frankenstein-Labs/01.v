import { GlButton, GlIcon, GlBadge } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LdapSyncItem from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_item.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import {
  ldapAdminRoleLinks,
  ROLE_LINK_NEVER_SYNCED,
  ROLE_LINK_QUEUED,
  ROLE_LINK_RUNNING,
  ROLE_LINK_SUCCESSFUL,
  ROLE_LINK_FAILED,
} from '../../mock_data';

const ALWAYS_SHOWN_FIELDS_COUNT = 4;

describe('LdapSyncItem component', () => {
  let wrapper;

  const createWrapper = ({ roleLink = ldapAdminRoleLinks[0] } = {}) => {
    wrapper = shallowMountExtended(LdapSyncItem, {
      propsData: { roleLink },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findDts = () => wrapper.findAll('dt');
  const findDds = () => wrapper.findAll('dd');
  const findServerName = () => findDds().at(0);
  const findDeleteButton = () => wrapper.findComponent(GlButton);
  const getUnknownServerIcon = () => findServerName().findComponent(GlIcon);
  const findStatusBadge = () => findDds().at(3).findComponent(GlBadge);
  const findMoreDetailsButton = () => findDds().at(3).findComponent(GlButton);
  const findDetailLabelAt = (index) => findDts().at(index + ALWAYS_SHOWN_FIELDS_COUNT);
  const findDetailValueAt = (index) => findDds().at(index + ALWAYS_SHOWN_FIELDS_COUNT);

  const expectLabelIconAndText = (index, icon, text) => {
    expect(findDetailLabelAt(index).findComponent(GlIcon).props('name')).toBe(icon);
    expect(findDetailLabelAt(index).text()).toBe(text);
  };

  const expectSyncCreated = (index) => {
    expectLabelIconAndText(index, 'file-addition', 'Sync created at:');
    expect(findDetailValueAt(index).text()).toBe('July 4, 2020 at 9:14:54 PM GMT (1 day ago)');
  };

  const expectSyncStarted = (index) => {
    expectLabelIconAndText(index, 'play', 'Started at:');
    expect(findDetailValueAt(index).text()).toBe('July 5, 2020 at 11:55:24 PM GMT (4 minutes ago)');
  };

  const expectSyncEnded = (index) => {
    expectLabelIconAndText(index, 'stop', 'Ended at:');
    expect(findDetailValueAt(index).text()).toBe('July 5, 2020 at 11:57:31 PM GMT (2 minutes ago)');
  };

  const expectTotalRuntime = (index) => {
    expectLabelIconAndText(index, 'timer', 'Total runtime:');
    expect(findDetailValueAt(index).text()).toBe('2 minutes');
  };

  const expectSyncError = (index) => {
    expectLabelIconAndText(index, 'error', 'Sync error:');
    expect(findDetailValueAt(index).text()).toBe('oh no');
  };

  const expectLastSuccessfulSync = (index) => {
    expectLabelIconAndText(index, 'check', 'Last successful sync:');
    expect(findDetailValueAt(index).text()).toBe('July 4, 2020 at 12:55:19 PM GMT (1 day ago)');
  };

  describe.each`
    roleLink                 | syncMethodLabel   | syncMethodValue                            | expectedServer | expectedRole
    ${ldapAdminRoleLinks[0]} | ${'User filter:'} | ${'cn=group1,ou=groups,dc=example,dc=com'} | ${'LDAP'}      | ${'Custom admin role 1'}
    ${ldapAdminRoleLinks[1]} | ${'Group cn:'}    | ${'group2'}                                | ${'LDAP alt'}  | ${'Custom admin role 2'}
  `(
    'for role link $roleLink.id',
    ({ roleLink, syncMethodLabel, syncMethodValue, expectedServer, expectedRole }) => {
      beforeEach(() => createWrapper({ roleLink }));

      it('shows server label', () => {
        expect(findDts().at(0).text()).toBe('Server:');
      });

      it('shows server name', () => {
        expect(findServerName().text()).toBe(expectedServer);
      });

      it('shows sync method label', () => {
        expect(findDts().at(1).text()).toBe(syncMethodLabel);
      });

      it('shows sync method value', () => {
        expect(findDds().at(1).text()).toBe(syncMethodValue);
      });

      it('shows custom admin role label', () => {
        expect(findDts().at(2).text()).toBe('Custom admin role:');
      });

      it('shows custom admin role name', () => {
        expect(findDds().at(2).text()).toBe(expectedRole);
      });

      describe('delete button', () => {
        it('shows button', () => {
          expect(findDeleteButton().attributes('aria-label')).toBe('Remove sync');
          expect(findDeleteButton().props()).toMatchObject({
            variant: 'danger',
            category: 'secondary',
            icon: 'remove',
          });
        });

        it('emits delete event when clicked', () => {
          findDeleteButton().vm.$emit('click');

          expect(wrapper.emitted('delete')).toHaveLength(1);
        });
      });
    },
  );

  describe('when LDAP server is unknown', () => {
    beforeEach(() => {
      ldapAdminRoleLinks[0].provider.label = null;
      createWrapper();
    });

    it('shows server id in orange', () => {
      expect(findServerName().text()).toBe('ldapmain');
      expect(findServerName().classes('gl-text-warning')).toBe(true);
    });

    it('shows unknown server icon', () => {
      expect(getUnknownServerIcon().props()).toMatchObject({
        name: 'warning-solid',
        variant: 'warning',
      });
    });

    it('shows unknown icon tooltip', () => {
      expect(getBinding(getUnknownServerIcon().element, 'gl-tooltip')).toMatchObject({
        value: 'Unknown LDAP server. Please check your server settings.',
        modifiers: { d0: true },
      });
    });
  });

  describe('sync status', () => {
    describe.each`
      roleLink                  | icon                      | variant      | text              | moreDetails
      ${ROLE_LINK_NEVER_SYNCED} | ${null}                   | ${'neutral'} | ${'Never synced'} | ${'More details'}
      ${ROLE_LINK_QUEUED}       | ${'status_pending'}       | ${'warning'} | ${'Queued'}       | ${'More details'}
      ${ROLE_LINK_RUNNING}      | ${'status_running'}       | ${'info'}    | ${'Running'}      | ${'4 minutes ago'}
      ${ROLE_LINK_SUCCESSFUL}   | ${'status_success_solid'} | ${'success'} | ${'Success'}      | ${'2 minutes ago'}
      ${ROLE_LINK_FAILED}       | ${'status_failed'}        | ${'danger'}  | ${'Failed'}       | ${'2 minutes ago'}
    `('for sync status $roleLink.syncStatus', ({ roleLink, icon, variant, text, moreDetails }) => {
      beforeEach(() => {
        createWrapper({ roleLink });
      });

      it('shows sync status label', () => {
        expect(findDts().at(3).text()).toBe('Sync status:');
      });

      it('shows sync status badge', () => {
        expect(findStatusBadge().text()).toBe(text);
        expect(findStatusBadge().props()).toMatchObject({ icon, variant });
      });

      it('shows more details button', () => {
        expect(findMoreDetailsButton().text()).toBe(moreDetails);
        expect(findMoreDetailsButton().props()).toMatchObject({ variant: 'link' });
        expect(findMoreDetailsButton().findComponent(GlIcon).props('name')).toBe('chevron-down');
      });

      it('does not show sync details', () => {
        expect(findDts()).toHaveLength(4);
        expect(findDds()).toHaveLength(4);
      });

      it('shows chevron up icon when more details button is clicked', async () => {
        findMoreDetailsButton().vm.$emit('click');
        await nextTick();

        expect(findMoreDetailsButton().findComponent(GlIcon).props('name')).toBe('chevron-up');
      });
    });

    describe('sync status details', () => {
      describe.each`
        roleLink                  | expectFns
        ${ROLE_LINK_NEVER_SYNCED} | ${[expectSyncCreated]}
        ${ROLE_LINK_QUEUED}       | ${[expectLastSuccessfulSync, expectSyncCreated]}
        ${ROLE_LINK_RUNNING}      | ${[expectSyncStarted, expectSyncCreated]}
        ${ROLE_LINK_SUCCESSFUL}   | ${[expectSyncStarted, expectSyncEnded, expectTotalRuntime, expectSyncCreated]}
        ${ROLE_LINK_FAILED}       | ${[expectSyncStarted, expectSyncEnded, expectTotalRuntime, expectSyncError, expectLastSuccessfulSync, expectSyncCreated]}
      `('for status $roleLink.syncStatus', ({ roleLink, expectFns }) => {
        beforeEach(() => {
          createWrapper({ roleLink });
          findMoreDetailsButton().vm.$emit('click');
        });

        it('has expected details count', () => {
          // The first 4 fields are for the other sync info, so we need to add on those.
          expect(findDts()).toHaveLength(expectFns.length + ALWAYS_SHOWN_FIELDS_COUNT);
          expect(findDds()).toHaveLength(expectFns.length + ALWAYS_SHOWN_FIELDS_COUNT);
        });

        it('has expected details', () => {
          expectFns.forEach((expectFn, index) => expectFn(index));
        });
      });
    });

    describe('when the sync details is expanded after some time has passed', () => {
      beforeEach(() => {
        jest.useFakeTimers({ legacyFakeTimers: false });

        const timestamp = '2020-07-05T23:59:40Z';
        createWrapper({
          roleLink: {
            ...ROLE_LINK_FAILED,
            createdAt: timestamp,
            syncStartedAt: timestamp,
            syncEndedAt: timestamp,
            lastSuccessfulSyncAt: timestamp,
          },
        });

        // Advance time by 5 seconds, then open the more details. We're verifying that the timeago
        // strings are based on the component mount time, not when the details are expanded.
        jest.advanceTimersByTime(5000);
        findMoreDetailsButton().vm.$emit('click');
      });

      it.each`
        description                  | findComponent
        ${'more details button'}     | ${findMoreDetailsButton}
        ${'sync started at'}         | ${() => findDetailValueAt(0)}
        ${'sync ended at'}           | ${() => findDetailValueAt(1)}
        ${'last successful sync at'} | ${() => findDetailValueAt(4)}
        ${'sync created at'}         | ${() => findDetailValueAt(5)}
      `('shows correct timeago for $description', ({ findComponent }) => {
        expect(findComponent().text()).toContain('20 seconds ago');
      });
    });
  });
});

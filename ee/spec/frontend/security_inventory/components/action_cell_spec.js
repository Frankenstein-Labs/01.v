import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import { isSubGroup } from 'ee/security_inventory/utils';
import {
  PROJECT_SECURITY_CONFIGURATION_PATH,
  PROJECT_VULNERABILITY_REPORT_PATH,
  GROUP_VULNERABILITY_REPORT_PATH,
} from 'ee/security_inventory/constants';
import { mockProjects, mockSubgroups } from '../mock_data';

describe('ActionCell', () => {
  let wrapper;

  const mockProject = mockProjects[0];
  const mockGroup = mockSubgroups[0];

  const createComponent = (
    props = {},
    provide = {
      glFeatures: { securityScanProfilesFeature: false },
      canManageAttributes: false,
      canApplyProfiles: false,
    },
  ) => {
    wrapper = shallowMountExtended(ActionCell, {
      propsData: {
        item: {},
        ...props,
      },
      provide,
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  const vulnerabilityPath = (item) =>
    isSubGroup(item)
      ? `${item.webUrl}${GROUP_VULNERABILITY_REPORT_PATH}`
      : `${item.webUrl}${PROJECT_VULNERABILITY_REPORT_PATH}`;

  describe.each`
    type         | item           | viewText           | showToolCoverage
    ${'project'} | ${mockProject} | ${'View project'}  | ${true}
    ${'group'}   | ${mockGroup}   | ${'View subgroup'} | ${false}
  `('when rendering $type item', ({ item, viewText, showToolCoverage }) => {
    beforeEach(() => {
      createComponent({ item });
    });

    it('renders GlDisclosureDropdown', () => {
      expect(findDropdown().exists()).toBe(true);
    });

    it('renders correct dropdown items', () => {
      const items = findDropdownItems().wrappers;
      const expectedLength = showToolCoverage ? 3 : 2;

      expect(items).toHaveLength(expectedLength);

      expect(items[0].props('item')).toMatchObject({
        text: viewText,
        href: item.webUrl,
      });

      expect(items[1].props('item')).toMatchObject({
        text: 'View vulnerability report',
        href: vulnerabilityPath(item),
      });

      if (showToolCoverage) {
        expect(items[2].props('item')).toMatchObject({
          text: 'Manage security configuration',
          href: `${item.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}`,
        });
      }
    });
  });

  describe('for project items', () => {
    beforeEach(() => {
      createComponent({ item: mockProject });
    });

    it('security configuration action has correct href', () => {
      const items = findDropdownItems().wrappers;

      expect(items[2].props('item')).toMatchObject({
        text: 'Manage security configuration',
        href: `${mockProject.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}`,
      });
    });
  });

  describe('with canManageAttributes permission', () => {
    beforeEach(() => {
      createComponent(
        { item: mockProject },
        {
          canManageAttributes: true,
          canApplyProfiles: false,
        },
      );
    });

    it('renders "Edit security attributes" action', () => {
      const items = findDropdownItems().wrappers;

      expect(items[3].props('item')).toMatchObject({
        text: 'Edit security attributes',
      });
    });

    it('attributes action emits "open-attributes-drawer"', () => {
      const items = findDropdownItems().wrappers;
      items[3].props('item').action();

      expect(wrapper.emitted('open-attributes-drawer')).toEqual([[mockProject]]);
    });
  });

  describe('with securityScanProfilesFeature feature flag enabled and canApplyProfiles permission', () => {
    beforeEach(() => {
      createComponent(
        { item: mockGroup },
        {
          glFeatures: { securityScanProfilesFeature: true },
          canManageAttributes: true,
          canApplyProfiles: true,
        },
      );
    });

    it('renders "Manage security scanners for subgroup projects" action', () => {
      expect(findDropdownItems().at(0).props('item')).toMatchObject({
        text: 'Manage security scanners for subgroup projects',
      });
    });

    it('emits "open-scanners-drawer" event when scanners action is clicked', () => {
      findDropdownItems().at(0).props('item').action();

      expect(wrapper.emitted('open-scanners-drawer')[0][0]).toEqual(mockGroup.id);
    });
  });

  describe('available actions', () => {
    describe.each`
      type         | item           | securityScanProfilesFeature | expectedItems
      ${'project'} | ${mockProject} | ${true}                     | ${['View project', 'View vulnerability report', 'Manage security configuration', 'Edit security attributes']}
      ${'group'}   | ${mockGroup}   | ${true}                     | ${['Manage security scanners for subgroup projects', 'View subgroup', 'View vulnerability report']}
      ${'group'}   | ${mockGroup}   | ${false}                    | ${['View subgroup', 'View vulnerability report']}
    `(
      'feature flags: when securityScanProfilesFeature is $securityScanProfilesFeature',
      ({ item, securityScanProfilesFeature, expectedItems }) => {
        beforeEach(() => {
          createComponent(
            { item },
            {
              glFeatures: { securityScanProfilesFeature },
              canApplyProfiles: true,
              canManageAttributes: true,
            },
          );
        });

        it('renders correct actions', () => {
          const items = findDropdownItems().wrappers.map((w) => w.props('item').text);

          expect(items).toStrictEqual(expectedItems);
        });
      },
    );

    describe.each`
      type         | item           | canApplyProfiles | canManageAttributes | expectedItems
      ${'project'} | ${mockProject} | ${true}          | ${true}             | ${['View project', 'View vulnerability report', 'Manage security configuration', 'Edit security attributes']}
      ${'project'} | ${mockProject} | ${true}          | ${false}            | ${['View project', 'View vulnerability report', 'Manage security configuration']}
      ${'group'}   | ${mockGroup}   | ${true}          | ${true}             | ${['Manage security scanners for subgroup projects', 'View subgroup', 'View vulnerability report']}
      ${'group'}   | ${mockGroup}   | ${false}         | ${true}             | ${['View subgroup', 'View vulnerability report']}
    `(
      'permissions: when canApplyProfiles is $canApplyProfiles and canManageAttributes is $canManageAttributes',
      ({ item, canApplyProfiles, canManageAttributes, expectedItems }) => {
        beforeEach(() => {
          createComponent(
            { item },
            {
              glFeatures: { securityScanProfilesFeature: true },
              canApplyProfiles,
              canManageAttributes,
            },
          );
        });

        it('renders correct actions', () => {
          const items = findDropdownItems().wrappers.map((w) => w.props('item').text);

          expect(items).toStrictEqual(expectedItems);
        });
      },
    );
  });
});

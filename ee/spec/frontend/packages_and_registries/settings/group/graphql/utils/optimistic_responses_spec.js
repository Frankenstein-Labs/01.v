import { updateVirtualRegistriesSettingOptimisticResponse } from 'ee_component/packages_and_registries/settings/group/graphql/utils/optimistic_responses';

describe('updateVirtualRegistriesSettingOptimisticResponse', () => {
  it('returns the correct structure', () => {
    expect(updateVirtualRegistriesSettingOptimisticResponse({ enabled: true }))
      .toMatchInlineSnapshot(`
{
  "__typename": "Mutation",
  "updateVirtualRegistriesSetting": {
    "__typename": "UpdateVirtualRegistriesSettingPayload",
    "errors": [],
    "virtualRegistriesSetting": {
      "__typename": "VirtualRegistriesSetting",
      "enabled": true,
    },
  },
}
`);
  });
});

export const updateVirtualRegistriesSettingOptimisticResponse = (changes) => ({
  __typename: 'Mutation',
  updateVirtualRegistriesSetting: {
    __typename: 'UpdateVirtualRegistriesSettingPayload',
    errors: [],
    virtualRegistriesSetting: {
      __typename: 'VirtualRegistriesSetting',
      ...changes,
    },
  },
});

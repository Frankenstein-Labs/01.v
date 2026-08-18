import { updateGroupVirtualRegistriesSetting } from 'ee_component/packages_and_registries/settings/group/graphql/utils/cache_update';
import getGroupVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_group_virtual_registries_setting.query.graphql';

describe('updateGroupVirtualRegistriesSetting', () => {
  let client;

  const cacheMock = {
    group: {
      virtualRegistriesSetting: {
        enabled: true,
      },
    },
  };

  const queryAndVariables = {
    query: getGroupVirtualRegistriesSetting,
    variables: { fullPath: 'foo' },
  };

  beforeEach(() => {
    client = {
      readQuery: jest.fn().mockReturnValue(cacheMock),
      writeQuery: jest.fn(),
    };
  });

  const payload = {
    data: {
      updateVirtualRegistriesSetting: {
        virtualRegistriesSetting: {
          enabled: false,
        },
      },
    },
  };

  describe('when updating the cache', () => {
    it('reads the cache with the correct query', () => {
      updateGroupVirtualRegistriesSetting('foo')(client, payload);
      expect(client.readQuery).toHaveBeenCalledWith(queryAndVariables);
    });

    it('writes the correct result to the cache', () => {
      updateGroupVirtualRegistriesSetting('foo')(client, payload);
      expect(client.writeQuery).toHaveBeenCalledWith({
        ...queryAndVariables,
        data: {
          group: {
            virtualRegistriesSetting: {
              enabled: false,
            },
          },
        },
      });
    });
  });

  describe('when cache is empty', () => {
    beforeEach(() => {
      client.readQuery.mockReturnValue(null);
      client.writeQuery.mockClear();
    });

    it('does not write to the store', () => {
      updateGroupVirtualRegistriesSetting('foo')(client, payload);
      expect(client.writeQuery).not.toHaveBeenCalled();
    });
  });

  describe('when virtualRegistriesSetting is missing', () => {
    beforeEach(() => {
      client.readQuery.mockReturnValue({ group: { virtualRegistriesSetting: null } });
      client.writeQuery.mockClear();
    });

    it('does not write to the store', () => {
      updateGroupVirtualRegistriesSetting('foo')(client, payload);
      expect(client.writeQuery).not.toHaveBeenCalled();
    });
  });
});

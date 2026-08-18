import { produce } from 'immer';
import getGroupVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_group_virtual_registries_setting.query.graphql';

export const updateGroupVirtualRegistriesSetting =
  (fullPath) =>
  (client, { data: updatedData }) => {
    const queryAndParams = {
      query: getGroupVirtualRegistriesSetting,
      variables: { fullPath },
    };

    const sourceData = client.readQuery(queryAndParams);

    if (!sourceData?.group?.virtualRegistriesSetting) {
      return;
    }

    const data = produce(sourceData, (draftState) => {
      Object.assign(
        draftState.group.virtualRegistriesSetting,
        updatedData.updateVirtualRegistriesSetting?.virtualRegistriesSetting || {},
      );
    });

    client.writeQuery({
      ...queryAndParams,
      data,
    });
  };

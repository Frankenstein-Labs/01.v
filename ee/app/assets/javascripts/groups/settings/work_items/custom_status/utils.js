import { STATUS_CATEGORIES_MAP } from 'ee/work_items/constants';

export const getSelectedStatus = (currentStatus, newStatusOptions) => {
  // check for same status
  const currentStatusExists = newStatusOptions.some((status) => status.id === currentStatus.id);

  if (currentStatusExists) {
    return currentStatus;
  }

  // use a status in the same category
  const sameCategoryStatuses = newStatusOptions.filter(
    (status) => status.category === currentStatus.category,
  );

  if (sameCategoryStatuses.length) {
    return sameCategoryStatuses[0];
  }

  return newStatusOptions[0];
};

export const getNewStatusOptionsFromTheSameState = (currentStatus, newStatusOptions) => {
  const currentStatusCategory = currentStatus.category.toUpperCase();
  const currentStatusState = STATUS_CATEGORIES_MAP[currentStatusCategory]?.workItemState;

  return newStatusOptions.filter((status) => {
    const statusCategory = status.category.toUpperCase();
    const statusState = STATUS_CATEGORIES_MAP[statusCategory]?.workItemState;
    return currentStatusState === statusState;
  });
};

export const excludeSelfReferencingIds = (statusMapping) => {
  return [...statusMapping].filter(({ oldStatusId, newStatusId }) => oldStatusId !== newStatusId);
};

export const getDefaultStatusMapping = (currentLifecycleStatuses, newLifecycleStatuses) => {
  const statusMappings = [];

  currentLifecycleStatuses.forEach((status) => {
    const statusMap = {};
    statusMap.oldStatusId = status.id;

    const eligibleItemsForNewStatus = getNewStatusOptionsFromTheSameState(
      status,
      newLifecycleStatuses,
    );
    const selectedStatus = getSelectedStatus(status, eligibleItemsForNewStatus);
    statusMap.newStatusId = selectedStatus.id;

    statusMappings.push(statusMap);
  });

  return statusMappings;
};

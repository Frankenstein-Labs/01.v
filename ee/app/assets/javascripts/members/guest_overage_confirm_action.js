import { sprintf } from '~/locale';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import createDefaultClient from '~/lib/graphql';
import getBillableUserCountChanges from '../invite_members/graphql/queries/billable_users_count.query.graphql';
import {
  GUEST_OVERAGE_MODAL_FIELDS,
  MEMBER_ACCESS_LEVELS,
  overageModalInfoText,
  overageModalInfoWarning,
} from './constants';

/**
 * Shows overage modal if the user's current access level is MINIMAL or GUEST.
 * It saves network requests.
 *
 * @param { Number } oldAccessLevel
 */
const shouldShowOverageModal = (oldAccessLevel) => {
  if (gon.features.showOverageOnRolePromotion && oldAccessLevel <= MEMBER_ACCESS_LEVELS.GUEST) {
    return true;
  }

  return false;
};

const getOverageData = async ({
  newRoleName,
  newMemberRoleId,
  groupPath,
  memberId,
  memberType,
}) => {
  const defaultClient = createDefaultClient();
  const response = await defaultClient.query({
    query: getBillableUserCountChanges,
    client: 'gitlabClient',
    fetchPolicy: 'no-cache',
    variables: {
      fullPath: groupPath,
      addGroupId: memberType === 'group' ? memberId : null,
      addUserEmails: [],
      addUserIds: memberType === 'user' ? [memberId] : null,
      role: newRoleName.toUpperCase(),
      memberRoleId: newMemberRoleId,
    },
  });

  return response?.data?.group?.gitlabSubscriptionsPreviewBillableUserChange;
};

const getConfirmContent = ({ subscriptionSeats, newBillableUserCount, groupName }) => {
  const infoText = overageModalInfoText(subscriptionSeats);
  const infoWarning = overageModalInfoWarning(newBillableUserCount, groupName);
  const link = sprintf(
    GUEST_OVERAGE_MODAL_FIELDS.LINK_TEXT,
    {
      linkStart: `<a href="${GUEST_OVERAGE_MODAL_FIELDS.LINK}" target="_blank">`,
      linkEnd: '</a>',
    },
    false,
  );

  return `${infoText} ${infoWarning} ${link}`;
};

export const guestOverageConfirmAction = async ({
  oldAccessLevel,
  newRoleName,
  newMemberRoleId,
  group,
  memberId,
  memberType,
}) => {
  if (!shouldShowOverageModal(oldAccessLevel)) {
    return true;
  }

  const overageData = await getOverageData({
    newRoleName,
    newMemberRoleId,
    groupPath: group.path,
    memberId,
    memberType,
  });

  // Allow user to proceed if willIncreaseOverage is false or if the backend doesn't
  // send the expected response, since we don't want this to be blocking.
  if (
    !overageData?.willIncreaseOverage ||
    overageData?.seatsInSubscription === undefined ||
    overageData?.newBillableUserCount === undefined
  ) {
    return true;
  }

  const confirmContent = getConfirmContent({
    subscriptionSeats: overageData.seatsInSubscription,
    newBillableUserCount: overageData.newBillableUserCount,
    groupName: group.name,
  });

  return confirmAction('', {
    title: GUEST_OVERAGE_MODAL_FIELDS.TITLE,
    modalHtmlMessage: confirmContent,
    primaryBtnText: GUEST_OVERAGE_MODAL_FIELDS.CONTINUE_BUTTON_LABEL,
    cancelBtnText: GUEST_OVERAGE_MODAL_FIELDS.BACK_BUTTON_LABEL,
  });
};

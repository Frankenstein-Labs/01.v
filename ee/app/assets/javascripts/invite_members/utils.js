import {
  membersProvideData as ceMembersProvideData,
  groupsProvideData as ceGroupsProvideData,
} from '~/invite_members/utils';

export function membersProvideData(el) {
  if (!el) {
    return false;
  }

  const result = ceMembersProvideData(el);

  return {
    ...result,
    rootGroupPath: el.dataset.rootGroupPath,
  };
}

export function groupsProvideData(el) {
  if (!el) {
    return false;
  }

  const result = ceGroupsProvideData(el);

  return {
    ...result,
    rootGroupPath: el.dataset.rootGroupPath,
  };
}

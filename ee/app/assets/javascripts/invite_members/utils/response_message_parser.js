import { responseFromSuccess as CeResponseFromSuccess } from '~/invite_members/utils/response_message_parser';

export function responseFromSuccess(response) {
  let usersWithWarning;
  const { error, message } = CeResponseFromSuccess(response);

  if (response.data.queued_users) {
    usersWithWarning = response.data.queued_users;
  }

  return { error, message, usersWithWarning };
}

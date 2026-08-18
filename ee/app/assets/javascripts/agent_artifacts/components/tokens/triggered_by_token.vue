<script>
import UserTokenFoss from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'TriggeredByToken',
  extends: UserTokenFoss,
  methods: {
    // The token value is the user's global ID (`valueField: 'id'`) so it can be
    // passed straight to `triggeredByUserId`, but the parent matches on
    // username. Match on either so the view slot renders name + avatar.
    // eslint-disable-next-line vue/no-unused-properties -- This component inherits from `UserTokenFoss` which calls `getActiveUser()` internally
    getActiveUser(users, data) {
      return users.find(
        (user) => user.id === data || user.username?.toLowerCase() === String(data).toLowerCase(),
      );
    },
  },
};
</script>

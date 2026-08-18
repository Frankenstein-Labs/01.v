<script>
import CEMembersTableCell from '~/members/components/table/members_table_cell.vue';
import { MEMBERS_TAB_TYPES } from 'ee_else_ce/members/constants';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import { canDisableTwoFactor, canOverride, canUnban } from '../../utils';

export default normalizeRender({
  name: 'MembersTableCellEE',
  inject: ['namespace'],
  props: {
    member: {
      type: Object,
      required: true,
    },
  },
  computed: {
    canDisableTwoFactor() {
      return canDisableTwoFactor(this.member);
    },
    canOverride() {
      return canOverride(this.member);
    },
    canUnban() {
      return canUnban(this.member);
    },
  },
  methods: {
    memberType(ceMemberType) {
      if (this.namespace === MEMBERS_TAB_TYPES.banned && this.member.banned) {
        return MEMBERS_TAB_TYPES.banned;
      }

      return ceMemberType;
    },
  },
  render(createElement) {
    return createElement(CEMembersTableCell, {
      props: { member: this.member },
      scopedSlots: {
        default: (props) => {
          return getSlotFunction(this)({
            ...props,
            memberType: this.memberType(props.memberType),
            permissions: {
              ...props.permissions,
              canOverride: this.canOverride,
              canUnban: this.canUnban,
              canDisableTwoFactor: this.canDisableTwoFactor,
              canBan: this.member.canBan && !this.member.banned,
            },
          });
        },
      },
    });
  },
});
</script>

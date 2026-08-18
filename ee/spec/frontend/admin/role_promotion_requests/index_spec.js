import { createWrapper } from '@vue/test-utils';
import initRolePromotionRequestsApp from 'ee/admin/role_promotion_requests/index';
import RolePromotionRequestsApp from 'ee/admin/role_promotion_requests/components/app.vue';

describe('initRolePromotionRequestsApp', () => {
  /** @type {HTMLDivElement} */
  let el;
  /** @type {Vue} */
  let vm;
  /** @type {import('@vue/test-utils').Wrapper<MembersTabs>} */
  let wrapper;

  const setup = () => {
    vm = initRolePromotionRequestsApp(el);
    wrapper = vm ? createWrapper(vm) : null;
  };

  beforeEach(() => {
    el = document.createElement('div');
    el.dataset.paths = JSON.stringify({ admin_user: '///' });

    document.body.appendChild(el);
  });

  afterEach(() => {
    el = null;
  });

  it('will render the RolePromotionRequestsApp', () => {
    setup();
    expect(wrapper.findComponent(RolePromotionRequestsApp).exists()).toBe(true);
  });

  it('wont render anything if mount element is null', () => {
    el = null;
    setup();
    expect(vm).toBe(null);
  });
});

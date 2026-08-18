// Easter egg: typing "do a barrel roll" into Duo Chat spins the whole UI once.
// Kept fully self-contained (phrase + match + animation) and away from chat
// business logic so it can be removed in a single change: delete this file and
// revert its handful of import sites (grep "barrel_roll" / "BarrelRoll").

const BARREL_ROLL_COMMAND = 'do a barrel roll';
const ANIMATION_NAME = 'duo-barrel-roll';
const STYLE_ELEMENT_ID = 'duo-barrel-roll-style';

/**
 * @param {string} prompt - A chat prompt.
 * @returns {boolean} Whether the prompt is the barrel-roll command.
 */
export const isBarrelRollCommand = (prompt) => prompt?.trim().toLowerCase() === BARREL_ROLL_COMMAND;

/**
 * Spin the entire interface 360° once. Injects a keyframe, rotates `<body>`,
 * then removes both once the animation ends so the DOM is left pristine and the
 * roll can be triggered again.
 */
const spin = () => {
  // Respect the user's motion preference: a full-viewport 360° spin is exactly
  // the kind of large motion prefers-reduced-motion exists to suppress.
  // eslint-disable-next-line @gitlab/require-i18n-strings
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;

  // The injected style doubles as the in-flight sentinel: ignore repeat
  // triggers while a roll is already running.
  if (document.getElementById(STYLE_ELEMENT_ID)) return;

  const style = document.createElement('style');
  style.id = STYLE_ELEMENT_ID;
  style.textContent = `@keyframes ${ANIMATION_NAME}{from{transform:rotate(0)}to{transform:rotate(360deg)}}`;
  document.head.appendChild(style);

  document.body.style.animation = `${ANIMATION_NAME} 1s ease-in-out`;
  const cleanup = () => {
    document.body.style.animation = '';
    style.remove();
  };
  const fallbackTimer = setTimeout(cleanup, 2000);
  document.body.addEventListener(
    'animationend',
    () => {
      clearTimeout(fallbackTimer);
      cleanup();
    },
    { once: true },
  );
};

/**
 * Perform the barrel roll when the prompt is the command.
 * @param {string} prompt - A chat prompt.
 * @returns {boolean} Whether the roll was triggered, i.e. whether the caller
 *   should treat the prompt as handled and not send it to the backend.
 */
export const maybeDoBarrelRoll = (prompt) => {
  if (!isBarrelRollCommand(prompt)) return false;
  spin();
  return true;
};

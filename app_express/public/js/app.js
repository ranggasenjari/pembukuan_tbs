document.addEventListener('submit', (event) => {
  const form = event.target;
  const message = form?.dataset?.confirm;
  if (message && !window.confirm(message)) {
    event.preventDefault();
  }
});

window.addEventListener('DOMContentLoaded', () => {
  if (window.lucide) {
    window.lucide.createIcons({
      attrs: {
        'stroke-width': 2
      }
    });
  }
});

document.querySelectorAll('input.uppercase, .uppercase input, input[name$="_name"], input[name="plate_number"]').forEach((input) => {
  input.addEventListener('input', () => {
    const start = input.selectionStart;
    input.value = input.value.toUpperCase();
    input.setSelectionRange(start, start);
  });
});

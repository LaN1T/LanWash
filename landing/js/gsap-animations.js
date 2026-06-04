gsap.registerPlugin(ScrollTrigger);

// ScrollTrigger instances are auto-managed by GSAP for static pages.

function scrollReveal(selector, fromVars, scrollTriggerConfig) {
  gsap.from(selector, {
    ...fromVars,
    scrollTrigger: scrollTriggerConfig,
  });
}

// Hero entrance animations (play immediately on page load)
gsap.from(".hero__title", {
  y: 60,
  opacity: 0,
  duration: 1,
  ease: "power3.out",
  delay: 0.2,
});

gsap.from(".hero__subtitle", {
  y: 40,
  opacity: 0,
  duration: 0.8,
  ease: "power3.out",
  delay: 0.5,
});

gsap.from(".hero .btn--primary", {
  scale: 0.8,
  opacity: 0,
  duration: 0.6,
  ease: "back.out(1.7)",
  delay: 0.8,
});

// Services cards stagger (scroll trigger)
scrollReveal(".service-card", {
  y: 50,
  opacity: 0,
  duration: 0.7,
  stagger: 0.1,
  ease: "power2.out",
}, {
  trigger: "#services",
  start: "top 80%",
});

// Why Us items (scroll trigger)
scrollReveal(".why-item", {
  y: 40,
  opacity: 0,
  duration: 0.6,
  stagger: 0.12,
  ease: "power2.out",
}, {
  trigger: "#why",
  start: "top 80%",
});

// Reviews carousel (scroll trigger)
scrollReveal(".reviews__carousel", {
  y: 30,
  opacity: 0,
  duration: 0.8,
  ease: "power2.out",
}, {
  trigger: "#reviews",
  start: "top 80%",
});

// Contacts (scroll trigger) — combined into a single timeline
const contactsTl = gsap.timeline({
  scrollTrigger: {
    trigger: "#contacts",
    start: "top 80%",
  },
});

contactsTl.from(".contacts__info", {
  x: -40,
  opacity: 0,
  duration: 0.7,
  ease: "power2.out",
});

contactsTl.from(".contacts__map", {
  x: 40,
  opacity: 0,
  duration: 0.7,
  ease: "power2.out",
});

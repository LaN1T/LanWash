gsap.registerPlugin(ScrollTrigger);

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
gsap.from(".service-card", {
  scrollTrigger: {
    trigger: "#services",
    start: "top 80%",
  },
  y: 50,
  opacity: 0,
  duration: 0.7,
  stagger: 0.1,
  ease: "power2.out",
});

// Why Us items (scroll trigger)
gsap.from(".why-item", {
  scrollTrigger: {
    trigger: "#why",
    start: "top 80%",
  },
  y: 40,
  opacity: 0,
  duration: 0.6,
  stagger: 0.12,
  ease: "power2.out",
});

// Reviews carousel (scroll trigger)
gsap.from(".reviews__carousel", {
  scrollTrigger: {
    trigger: "#reviews",
    start: "top 80%",
  },
  y: 30,
  opacity: 0,
  duration: 0.8,
  ease: "power2.out",
});

// Contacts (scroll trigger)
gsap.from(".contacts__info", {
  scrollTrigger: {
    trigger: "#contacts",
    start: "top 80%",
  },
  x: -40,
  opacity: 0,
  duration: 0.7,
  ease: "power2.out",
});

gsap.from(".contacts__map", {
  scrollTrigger: {
    trigger: "#contacts",
    start: "top 80%",
  },
  x: 40,
  opacity: 0,
  duration: 0.7,
  ease: "power2.out",
});

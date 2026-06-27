/// Context for selecting a strategic brand message.
enum MessageContext {
  home,
  milestoneComplete,
  paymentComplete,
  photosUploaded,
  projectComplete,
}

/// Returns warm, brand-aligned messages shown contextually across the portal.
class PortalMessageService {
  const PortalMessageService._();

  static String getContextualMessage(MessageContext context) {
    switch (context) {
      case MessageContext.home:
        return _dailyMessages[DateTime.now().day % _dailyMessages.length];
      case MessageContext.milestoneComplete:
        return '🎉 Another milestone achieved. Your home is getting closer.';
      case MessageContext.paymentComplete:
        return '✅ Thank you for your trust. Payment received safely.';
      case MessageContext.photosUploaded:
        return "📸 New photos from your site — see today's progress.";
      case MessageContext.projectComplete:
        return '🏡 Your home is ready. It has been an honour building it.';
    }
  }

  static const _dailyMessages = [
    'Every detail. Every finish. Every moment.',
    "We don't just build spaces. We build your dreams.",
    'Luxury is built one detail at a time.',
    "Today's work brings you one step closer to your dream home.",
    'Your home deserves patience, precision and passion.',
    'Great homes are not completed overnight. They are perfected every single day.',
    'Every brick we place is a promise we keep.',
    'Thank you for trusting us with your most important space.',
    "Our craftsmen don't just build furniture. They build family moments.",
    'Your dream. Our design. A perfect combination.',
    "We don't meet expectations. We exceed them.",
    'From the first sketch to the final handover, we walk with you.',
    'Quality is not an act. It is a habit we build every day.',
    'Your trust. Our responsibility.',
    'A home is not just made of walls and roofs. It is built with love.',
  ];
}

import { motion } from "motion/react";
import type { ReactNode } from "react";

/** Fades + lifts children in with a stagger (Motion Primitives "animated group"). */
export function AnimatedGroup({
  children,
  className,
  stagger = 0.07,
}: {
  children: ReactNode;
  className?: string;
  stagger?: number;
}) {
  const items = Array.isArray(children) ? children : [children];
  return (
    <motion.div
      className={className}
      initial="hidden"
      animate="visible"
      variants={{ hidden: {}, visible: { transition: { staggerChildren: stagger } } }}
    >
      {items.map((child, i) => (
        <motion.div
          key={i}
          variants={{
            hidden: { opacity: 0, y: 14, filter: "blur(6px)" },
            visible: { opacity: 1, y: 0, filter: "blur(0px)", transition: { duration: 0.5, ease: "easeOut" } },
          }}
        >
          {child}
        </motion.div>
      ))}
    </motion.div>
  );
}

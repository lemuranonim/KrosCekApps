package com.kroscek.build;

import com.android.build.api.instrumentation.AsmClassVisitorFactory;
import com.android.build.api.instrumentation.ClassContext;
import com.android.build.api.instrumentation.ClassData;
import com.android.build.api.instrumentation.InstrumentationParameters;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.FieldVisitor;
import org.objectweb.asm.Handle;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;

/** Keep internal receivers protected by the new certificate during key rotation. */
public abstract class ReceiverPermissionVisitor
        implements AsmClassVisitorFactory<InstrumentationParameters.None> {
    static final String OLD = ".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION";
    static final String NEW = ".KROSCEK_RECEIVER_NOT_EXPORTED_PERMISSION";

    @Override public boolean isInstrumentable(ClassData data) {
        return data.getClassName().replace('/', '.').equals("androidx.core.content.ContextCompat");
    }

    @Override public ClassVisitor createClassVisitor(ClassContext context, ClassVisitor next) {
        return rewrite(next);
    }

    static ClassVisitor rewrite(ClassVisitor next) {
        return new ClassVisitor(Opcodes.ASM9, next) {
            private int replacements;

            private Object replace(Object value) {
                if (value instanceof String && ((String) value).contains(OLD)) {
                    replacements++;
                    return ((String) value).replace(OLD, NEW);
                }
                return value;
            }

            @Override public FieldVisitor visitField(int access, String name, String descriptor,
                    String signature, Object value) {
                return super.visitField(access, name, descriptor, signature, replace(value));
            }

            @Override public MethodVisitor visitMethod(int access, String name, String descriptor,
                    String signature, String[] exceptions) {
                return new MethodVisitor(Opcodes.ASM9,
                        super.visitMethod(access, name, descriptor, signature, exceptions)) {
                    @Override public void visitLdcInsn(Object value) {
                        super.visitLdcInsn(replace(value));
                    }
                    @Override public void visitInvokeDynamicInsn(String name, String descriptor,
                            Handle bootstrap, Object... arguments) {
                        Object[] updated = arguments.clone();
                        for (int i = 0; i < updated.length; i++) updated[i] = replace(updated[i]);
                        super.visitInvokeDynamicInsn(name, descriptor, bootstrap, updated);
                    }
                };
            }

            @Override public void visitEnd() {
                if (replacements == 0) {
                    throw new IllegalStateException("AndroidX receiver permission changed; review signing migration");
                }
                super.visitEnd();
            }
        };
    }
}

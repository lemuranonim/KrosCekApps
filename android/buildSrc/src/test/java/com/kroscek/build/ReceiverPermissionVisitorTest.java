package com.kroscek.build;

import org.junit.Test;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import static org.junit.Assert.*;

public class ReceiverPermissionVisitorTest {
    private byte[] fixture(String suffix) {
        ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_MAXS);
        writer.visit(Opcodes.V17, Opcodes.ACC_PUBLIC, "PermissionFixture", null, "java/lang/Object", null);
        writer.visitField(Opcodes.ACC_PUBLIC | Opcodes.ACC_STATIC | Opcodes.ACC_FINAL,
                "SUFFIX", "Ljava/lang/String;", null, suffix).visitEnd();
        MethodVisitor method = writer.visitMethod(Opcodes.ACC_PUBLIC | Opcodes.ACC_STATIC,
                "permission", "()Ljava/lang/String;", null, null);
        method.visitCode(); method.visitLdcInsn("com.example.kroscek" + suffix);
        method.visitInsn(Opcodes.ARETURN); method.visitMaxs(1, 0); method.visitEnd();
        writer.visitEnd(); return writer.toByteArray();
    }

    @Test public void updatesFieldAndRuntimeConstantWithoutChangingProtection() throws Exception {
        ClassWriter writer = new ClassWriter(0);
        new ClassReader(fixture(ReceiverPermissionVisitor.OLD)).accept(ReceiverPermissionVisitor.rewrite(writer), 0);
        byte[] result = writer.toByteArray();
        Class<?> type = new ClassLoader() {
            Class<?> loadFixture() { return defineClass("PermissionFixture", result, 0, result.length); }
        }.loadFixture();
        assertEquals(ReceiverPermissionVisitor.NEW, type.getField("SUFFIX").get(null));
        assertEquals("com.example.kroscek" + ReceiverPermissionVisitor.NEW,
                type.getMethod("permission").invoke(null));
    }

    @Test(expected = IllegalStateException.class)
    public void changedUpstreamLibraryFailsClosed() {
        new ClassReader(fixture(".unexpected")).accept(ReceiverPermissionVisitor.rewrite(new ClassWriter(0)), 0);
    }
}

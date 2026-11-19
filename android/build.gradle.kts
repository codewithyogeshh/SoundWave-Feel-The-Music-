allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force every plugin module to a modern compileSdk. Some plugins (e.g.
// on_audio_query_android) still declare compileSdk 33 while their androidx
// dependencies require 34+, which fails the release AAR metadata check.
fun applyCompileSdk(ext: Any, sdk: Int) {
    runCatching {
        val current = ext.javaClass.getMethod("getCompileSdk").invoke(ext)
        if (current is org.gradle.api.provider.Property<*>) {
            current.javaClass.getMethod("set", Any::class.java).invoke(current, sdk)
            return
        }
    }
    runCatching {
        ext.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(ext, sdk)
    }
    runCatching {
        ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, sdk)
    }
    runCatching {
        ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, sdk)
    }
}

subprojects {
    // afterEvaluate so plugin scripts that set their own compileSdk cannot override us.
    afterEvaluate {
        plugins.withId("com.android.library") {
            val androidExt = project.extensions.findByName("android") ?: return@withId
            applyCompileSdk(androidExt, 36)

            runCatching {
                val namespace = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespace == null) {
                    val ns = if (project.name.contains("on_audio_query")) {
                        "com.lucasjosino.on_audio_query"
                    } else {
                        "com.soundwave.plugin.${project.name.replace('-', '_')}"
                    }
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, ns)
                }
            }
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    project.tasks.whenTaskAdded {
        if (name.contains("compile") && name.contains("Kotlin")) {
            try {
                val getKotlinOptions = javaClass.getMethod("getKotlinOptions")
                val kotlinOptions = getKotlinOptions.invoke(this)
                val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "17")
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

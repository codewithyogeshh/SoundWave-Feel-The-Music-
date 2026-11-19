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
            current.set(sdk)
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
            try {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=")) {
                        val newContent = content.replace(Regex("""package="[^"]*"""), "")
                        manifestFile.writeText(newContent)
                    }
                }

                val androidExt = project.extensions.findByName("android")
                if (androidExt != null) {
                    applyCompileSdk(androidExt, 36)

                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    if (getNamespace.invoke(androidExt) == null) {
                        val ns = if (project.name.contains("on_audio_query")) {
                            "com.lucasjosino.on_audio_query"
                        } else {
                            "com.soundwave.plugin.${project.name.replace('-', '_')}"
                        }
                        setNamespace.invoke(androidExt, ns)
                    }
                }
            } catch (_: Exception) {}
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

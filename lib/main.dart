import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:file_picker/file_picker.dart'; // For photo picking
import 'package:google_fonts/google_fonts.dart'; // For edgy fonts
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // PDF widgets
import 'dart:typed_data'; // For web-friendly bytes
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RevLog',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: GoogleFonts.racingSansOneTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class Car {
  String name;
  String? description;
  List<Task> tasks;
  List<Photo> photos;
  String? coverPhoto;
  bool isExpanded;
  Car(this.name, this.tasks, this.photos, {this.description, this.coverPhoto, this.isExpanded = true});
}

class Task {
  String description;
  DateTime dateAdded;
  DateTime? reminderDate;
  Task(this.description, {required this.dateAdded, this.reminderDate});
}

class Photo {
  String fileName;
  DateTime dateAdded;
  Uint8List? imageBytes;
  Photo(this.fileName, {required this.dateAdded, this.imageBytes});
}

class _MyHomePageState extends State<MyHomePage> {
  List<Car> cars = [
    Car("Porsche 911", [Task("Oil Change", dateAdded: DateTime.now())], []),
  ];
  Map<Car, TextEditingController> taskControllers = {};
  TextEditingController newCarController = TextEditingController();
  TextEditingController editTaskController = TextEditingController();
  TextEditingController editCarController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController garageController = TextEditingController(text: "Garage");
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    for (var car in cars) {
      taskControllers[car] = TextEditingController();
    }
  }

  void addTaskToCar(Car car) {
    String taskDesc = taskControllers[car]!.text.trim();
    if (taskDesc.isNotEmpty) {
      setState(() {
        car.tasks.add(Task(taskDesc, dateAdded: DateTime.now()));
        taskControllers[car]!.clear();
      });
      print("Task added: $taskDesc to ${car.name}");
    }
  }

Future<void> addPhotoToCar(Car car) async {
  print("Opening file picker for photo in ${car.name}");
  if (!isPremium && car.photos.length >= 10) {
    showPremiumPrompt(context);
    return;
  }
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result != null && result.files.single.name.isNotEmpty) {
    Uint8List? imageBytes;
    if (result.files.single.bytes != null) {
      imageBytes = result.files.single.bytes; // Web/Chrome
    } else if (result.files.single.path != null) {
      imageBytes = await File(result.files.single.path!).readAsBytes(); // iOS
    }
    setState(() {
      car.photos.add(Photo(
        result.files.single.name,
        dateAdded: DateTime.now(),
        imageBytes: imageBytes,
      ));
    });
    print("Photo picked: ${result.files.single.name}");
  } else {
    print("No photo selected");
  }
}

  Future<void> setReminderDate(BuildContext context, Task task) async {
    print("Setting reminder for: ${task.description}");
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.grey[850]),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        task.reminderDate = picked;
      });
      print("Reminder set to: ${DateFormat('MM/dd/yy').format(picked)}");
    }
  }

  Future<void> exportRevLogToPDF(Car car, BuildContext context) async {
    if (isPremium) {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, text: "RevLog Report - ${car.name}"),
              pw.SizedBox(height: 20),
              pw.Text(car.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (car.description != null) pw.Text("Specs: ${car.description}", style: pw.TextStyle(fontSize: 14)),
              if (car.coverPhoto != null) pw.Text("Cover Photo: ${car.coverPhoto}", style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text("Tasks:", style: pw.TextStyle(fontSize: 14)),
              for (var task in car.tasks)
                pw.Text(
                  "${DateFormat('MM/dd/yy').format(task.dateAdded)} - ${task.description}${task.reminderDate != null ? " (Reminder: ${DateFormat('MM/dd/yy').format(task.reminderDate!)})" : ""}",
                  style: pw.TextStyle(fontSize: 12),
                ),
              pw.Text("Photos:", style: pw.TextStyle(fontSize: 14)),
              for (var photo in car.photos)
                pw.Text("${DateFormat('MM/dd/yy').format(photo.dateAdded)} - ${photo.fileName}", style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      await FilePicker.platform.saveFile(
        dialogTitle: "Save RevLog PDF",
        fileName: "RevLog_${car.name}_${DateTime.now().toIso8601String().substring(0, 10)}.pdf",
        bytes: bytes,
      );
      print("PDF exported for: ${car.name}");
    } else {
      showPremiumPrompt(context);
    }
  }

  void showPremiumPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text("Upgrade to Premium", style: GoogleFonts.racingSansOne(color: Colors.white)),
          content: const Text(
            "Unlock unlimited cars, photos, PDF exports, and more with Premium for just \$6.99/month!",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print("Upgrade pressed");
                Navigator.pop(dialogContext);
                // TODO: Navigate to subscription page
              },
              child: Text("Upgrade", style: GoogleFonts.racingSansOne(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void editTask(Task task, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(task.dateAdded);
    if (diff.inHours > 24) {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.grey[850],
            title: Text("Edit Locked", style: GoogleFonts.racingSansOne(color: Colors.white)),
            content: const Text(
              "Tasks can only be edited within 24 hours of being added.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("OK", style: GoogleFonts.racingSansOne(color: Colors.white)),
              ),
            ],
          );
        },
      );
      return;
    }

    print("Editing task: ${task.description}");
    editTaskController.text = task.description;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text("Edit Task", style: GoogleFonts.racingSansOne(color: Colors.white)),
          content: TextField(
            controller: editTaskController,
            decoration: const InputDecoration(
              labelText: "Task description",
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.done,
            onSubmitted: (text) {
              if (text.isNotEmpty) {
                setState(() {
                  task.description = text;
                });
                Navigator.pop(dialogContext);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (editTaskController.text.isNotEmpty) {
                  setState(() {
                    task.description = editTaskController.text;
                  });
                  Navigator.pop(dialogContext);
                }
              },
              child: Text("Save", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void editCarDetails(Car car, BuildContext context) {
    print("Editing vehicle: ${car.name}");
    editCarController.text = car.name;
    descriptionController.text = car.description ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text("Edit ${car.name}", style: GoogleFonts.racingSansOne(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editCarController,
                decoration: const InputDecoration(
                  labelText: "Vehicle name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: "Specifications/Description",
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (editCarController.text.isNotEmpty) {
                  setState(() {
                    car.name = editCarController.text;
                    car.description = descriptionController.text;
                  });
                  Navigator.pop(dialogContext);
                }
              },
              child: Text("Save", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void showNewCarDialog(BuildContext context) {
    print("Function showNewCarDialog called");
    newCarController.clear();
    if (!isPremium && cars.length >= 2) {
      showPremiumPrompt(context);
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.grey[850],
            title: Text("Add New Vehicle", style: GoogleFonts.racingSansOne(color: Colors.white)),
            content: TextField(
              controller: newCarController,
              decoration: const InputDecoration(
                labelText: "Vehicle name",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  setState(() {
                    var newCar = Car(text, [], []);
                    cars.add(newCar);
                    taskControllers[newCar] = TextEditingController();
                  });
                  Navigator.pop(dialogContext);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  String newCarName = newCarController.text;
                  if (newCarName.isNotEmpty) {
                    setState(() {
                      var newCar = Car(newCarName, [], []);
                      cars.add(newCar);
                      taskControllers[newCar] = TextEditingController();
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text("Save", style: GoogleFonts.racingSansOne(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("Cancel", style: GoogleFonts.racingSansOne(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text("Settings", style: GoogleFonts.racingSansOne(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.name.isNotEmpty) {
                      setState(() {
                        cars[0].coverPhoto = result.files.single.name; // Default to first car
                      });
                      print("Cover photo set: ${result.files.single.name}");
                    }
                  },
                  child: Text("Set Cover Photo", style: GoogleFonts.racingSansOne()),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    showDialog(
                      context: context,
                      builder: (garageContext) {
                        return AlertDialog(
                          backgroundColor: Colors.grey[850],
                          title: Text("Change Garage Name", style: GoogleFonts.racingSansOne(color: Colors.white)),
                          content: TextField(
                            controller: garageController,
                            decoration: const InputDecoration(
                              labelText: "Garage name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                if (garageController.text.isNotEmpty) {
                                  setState(() {});
                                  Navigator.pop(garageContext);
                                }
                              },
                              child: Text("Save", style: GoogleFonts.racingSansOne(color: Colors.white)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(garageContext),
                              child: Text("Cancel", style: GoogleFonts.racingSansOne(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text("Change Garage Name", style: GoogleFonts.racingSansOne()),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => exportRevLogToPDF(cars[0], context), // Default to first car
                  child: Text("Export RevLog", style: GoogleFonts.racingSansOne()),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => showPremiumPrompt(context),
                  child: Text("Upgrade to Premium", style: GoogleFonts.racingSansOne()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Close", style: GoogleFonts.racingSansOne(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.speed, color: Colors.redAccent, size: 32),
            const SizedBox(width: 8),
            Text("RevLog", style: GoogleFonts.racingSansOne(fontSize: 32)),
          ],
        ),
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(garageController.text, style: const TextStyle(fontSize: 20)),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => showNewCarDialog(context),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cars.length,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      cars[index].name,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    if (cars[index].coverPhoto != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Text(
                                          "[Cover: ${cars[index].coverPhoto}]",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                if (cars[index].description != null && cars[index].description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      cars[index].description!,
                                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => editCarDetails(cars[index], context),
                                  child: const Text("Edit"),
                                ),
                                IconButton(
                                  icon: Icon(cars[index].isExpanded ? Icons.expand_less : Icons.expand_more),
                                  color: Colors.white,
                                  onPressed: () {
                                    setState(() {
                                      cars[index].isExpanded = !cars[index].isExpanded;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (cars[index].isExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                            },
                            child: TextField(
                              controller: taskControllers[cars[index]],
                              decoration: const InputDecoration(
                                labelText: "Enter Log",
                                labelStyle: TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (text) {
                                taskControllers[cars[index]]!.text += '\n';
                                taskControllers[cars[index]]!.selection = TextSelection.fromPosition(
                                  TextPosition(offset: taskControllers[cars[index]]!.text.length),
                                );
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => addTaskToCar(cars[index]),
                              child: const Text("Submit"),
                            ),
                            ElevatedButton(
                              onPressed: () => addPhotoToCar(cars[index]),
                              child: const Text("Add Photo"),
                            ),
                          ],
                        ),
                        ...cars[index].tasks.map((task) {
                          return ListTile(
                            leading: Text(
                              DateFormat('MM/dd/yy').format(task.dateAdded),
                              style: const TextStyle(fontSize: 16, color: Colors.white70),
                            ),
                            title: Text(
                              task.description,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: Colors.white,
                                  onPressed: () => editTask(task, context),
                                ),
                                GestureDetector(
                                  onTap: () => setReminderDate(context, task),
                                  child: task.reminderDate != null
                                      ? Text(
                                          "Reminder: ${DateFormat('MM/dd/yy').format(task.reminderDate!)}",
                                          style: const TextStyle(color: Colors.blue),
                                        )
                                      : const Icon(Icons.alarm_off, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }),
                        ...cars[index].photos.map((photo) {
                          return ListTile(
    leading: Text(
      DateFormat('MM/dd/yy').format(photo.dateAdded),
      style: const TextStyle(fontSize: 16, color: Colors.white70),
    ),
    title: photo.imageBytes != null
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.3, // 30% of screen width
              maxHeight: 100, // Cap height to avoid overflow
            ),
            child: Image.memory(
              photo.imageBytes!,
              fit: BoxFit.contain, // Preserves aspect ratio
            ),
          )
        : Text(
            "Photo: ${photo.fileName}",
            style: const TextStyle(color: Colors.white70),
          ),
    trailing: const Icon(Icons.image, color: Colors.green),
  );
}),
                      ],
                      const Divider(color: Colors.white54),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
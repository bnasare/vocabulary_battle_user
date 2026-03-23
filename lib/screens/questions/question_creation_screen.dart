import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../../models/question_model.dart';
import '../../providers/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/loading/async_loader.dart';

class QuestionCreationScreen extends ConsumerStatefulWidget {
  final GameSession session;

  const QuestionCreationScreen({super.key, required this.session});

  @override
  ConsumerState<QuestionCreationScreen> createState() =>
      _QuestionCreationScreenState();
}

class _QuestionCreationScreenState
    extends ConsumerState<QuestionCreationScreen> {
  int _currentStep =
      0; // 0=select letters, 1-3=create for each letter, 4=random
  List<String> _selectedLetters = [];
  final Map<int, List<QuestionDraft>> _questions = {
    1: [],
    2: [],
    3: [],
    4: [], // random
  };

  final _definitionController = TextEditingController();
  final _answerController = TextEditingController();

  // Edit mode tracking
  int? _editingLetterOrder;
  int? _editingIndex;
  bool get _isEditMode => _editingLetterOrder != null && _editingIndex != null;

  // AI mode tracking
  bool _useAI = false;
  bool _hasUsedAI = false;
  int _aiRegenerationsLeft = 1;

  @override
  void initState() {
    super.initState();
    _loadDraft();

    // Add listeners to text controllers to update button state
    _definitionController.addListener(_updateFormState);
    _answerController.addListener(_updateFormState);
  }

  void _updateFormState() {
    // Trigger rebuild when text changes
    setState(() {});
  }

  @override
  void dispose() {
    _definitionController.removeListener(_updateFormState);
    _answerController.removeListener(_updateFormState);
    _definitionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    // Load from Hive if exists
    final box = await Hive.openBox('question_drafts');
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return; // Safety check

    final draft = box.get('${widget.session.id}_$userId');
    if (draft != null && draft is Map) {
      setState(() {
        _selectedLetters = List<String>.from(draft['letters'] ?? []);
        if (_selectedLetters.length == 3) {
          _currentStep = 1;
        }
        // Load saved questions
        final questionsData = draft['questions'];
        if (questionsData is Map) {
          for (var entry in questionsData.entries) {
            final letterOrder = int.parse(entry.key.toString());
            if (entry.value is List) {
              _questions[letterOrder] = (entry.value as List)
                  .map((q) => QuestionDraft.fromMap(q))
                  .toList();
            }
          }
        }
      });
    }
  }

  Future<void> _saveDraft() async {
    final box = await Hive.openBox('question_drafts');
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return; // Safety check

    await box.put('${widget.session.id}_$userId', {
      'letters': _selectedLetters,
      'questions': _questions.map((key, value) =>
          MapEntry(key.toString(), value.map((q) => q.toMap()).toList())),
    });
  }

  Future<void> _generateAIQuestions() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Ensure 3 letters are selected
    if (_selectedLetters.length != 3) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context,
          'Please select 3 letters first',
        );
      }
      return;
    }

    final result = await AsyncLoader.execute<Map<String, dynamic>>(
      context: context,
      message: 'AI is generating questions for ${_selectedLetters.join(', ')}...',
      asyncTask: () async {
        final aiService = ref.read(aiQuestionServiceProvider);
        return await aiService.generateQuestions(
          selectedLetters: _selectedLetters,
          gameMode: widget.session.gameMode,
          creatorId: userId,
        );
      },
      timeout: const Duration(seconds: 30),
    );

    result.fold(
      (error) {
        if (mounted) {
          SnackBarHelper.showErrorSnackBar(
            context,
            'AI generation failed: $error',
          );
        }
      },
      (data) {
        // Extract generated data
        final generatedQuestions = data['questions'] as List<Question>;

        // Group questions by letter order
        setState(() {
          _questions[1] = [];
          _questions[2] = [];
          _questions[3] = [];
          _questions[4] = [];

          for (final question in generatedQuestions) {
            final draft = QuestionDraft(
              definition: question.definition,
              answer: question.answer,
              letter: question.letter,
            );

            _questions[question.letterOrder]!.add(draft);
          }

          _hasUsedAI = true;
          if (_aiRegenerationsLeft > 0) {
            _aiRegenerationsLeft--;
          }
          _currentStep = 1; // Move to first letter screen
        });

        _saveDraft();

        if (mounted) {
          final remainingText = _aiRegenerationsLeft > 0
              ? ' You can regenerate once more if needed.'
              : '';
          SnackBarHelper.showSuccessSnackBar(
            context,
            'AI generated ${generatedQuestions.length} questions! You can edit them now.$remainingText',
          );
        }
      },
    );
  }

  Future<bool> _showSaveDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save your progress?'),
          content: const Text(
            'Do you want to save your letter selections as a draft?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text(
                'Discard',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('Save Draft'),
            ),
          ],
        );
      },
    );

    if (result == 'save') {
      await _saveDraft();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    // If null (dismissed), stay on current screen
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If on letter selection step and letters are selected, ask before saving
        if (_currentStep == 0 && _selectedLetters.isNotEmpty) {
          return await _showSaveDialog();
        }
        // For other steps, auto-save as before
        await _saveDraft();
        return true;
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping anywhere on the screen
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text('Create Questions'),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            actions: [
              if (_currentStep > 0)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: Colors.green[300],
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Auto-saved',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: _currentStep == 0
              ? _buildLetterSelection()
              : _currentStep <= 3
                  ? _buildQuestionCreation(_currentStep)
                  : _buildRandomQuestions(),
        ),
      ),
    );
  }

  Widget _buildLetterSelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select 3 Letters',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll create ${widget.session.questionsPerLetter} questions for each letter',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Selected letters display
          if (_selectedLetters.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._selectedLetters.map((letter) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Chip(
                          label: Text(
                            letter,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: AppColors.primary,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Alphabet grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: AppConstants.alphabet.length,
              itemBuilder: (context, index) {
                final letter = AppConstants.alphabet[index];
                final isSelected = _selectedLetters.contains(letter);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLetters.remove(letter);
                      } else if (_selectedLetters.length < 3) {
                        _selectedLetters.add(letter);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // AI Mode Toggle (only enabled when 3 letters selected)
          Opacity(
            opacity: _selectedLetters.length == 3 ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _useAI ? IconlyBold.star : IconlyLight.star,
                    color: _useAI && _selectedLetters.length == 3
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Question Generation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLetters.length == 3
                              ? (_useAI
                                  ? 'AI will generate questions for letters ${_selectedLetters.join(', ')}'
                                  : 'Toggle to use AI for selected letters')
                              : 'Select 3 letters first to enable AI',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _useAI,
                    onChanged: (_hasUsedAI || _selectedLetters.length != 3)
                        ? null
                        : (value) {
                            setState(() {
                              _useAI = value;
                            });
                          },
                    activeColor: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _selectedLetters.length == 3
                  ? () {
                      if (_useAI && !_hasUsedAI) {
                        _generateAIQuestions();
                      } else {
                        setState(() => _currentStep = 1);
                        _saveDraft();
                      }
                    }
                  : null,
              icon: _useAI && !_hasUsedAI
                  ? const Icon(IconlyBold.star)
                  : const Icon(IconlyLight.arrow_right_3),
              label: Text(
                _selectedLetters.length == 3
                    ? (_useAI && !_hasUsedAI
                        ? 'Generate with AI'
                        : 'Continue')
                    : 'Select ${3 - _selectedLetters.length} more letter${3 - _selectedLetters.length != 1 ? 's' : ''}',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuestionCreation(int letterOrder) {
    final letter = _selectedLetters[letterOrder - 1];
    final letterQuestions = _questions[letterOrder] ?? [];
    final currentIndex = letterQuestions.length;
    final isComplete = currentIndex >= widget.session.questionsPerLetter;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: LetterColors.getColorForLetterOrder(letterOrder),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Letter $letter Questions',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_hasUsedAI)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              IconlyBold.star,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${letterQuestions.length}/${widget.session.questionsPerLetter} completed',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasUsedAI && _aiRegenerationsLeft > 0 && letterOrder <= 3)
                IconButton(
                  icon: const Icon(CupertinoIcons.refresh),
                  tooltip: 'Regenerate with AI',
                  onPressed: _generateAIQuestions,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          LinearProgressIndicator(
            value: letterQuestions.length / widget.session.questionsPerLetter,
            backgroundColor: Colors.grey[200],
            color: LetterColors.getColorForLetterOrder(letterOrder),
          ),
          const SizedBox(height: 24),

          // Question list
          if (letterQuestions.isNotEmpty) ...[
            const Text(
              'Created Questions:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: letterQuestions.length,
                itemBuilder: (context, index) {
                  final q = letterQuestions[index];
                  final isBeingEdited = _isEditMode &&
                      _editingLetterOrder == letterOrder &&
                      _editingIndex == index;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isBeingEdited
                        ? AppColors.primary.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            LetterColors.getColorForLetterOrder(letterOrder),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(q.definition,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('Answer: ${q.answer}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _startEditingQuestion(letterOrder, index),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(IconlyLight.edit,
                                  color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                letterQuestions.removeAt(index);
                                // Cancel edit if deleting the currently edited question
                                if (isBeingEdited) {
                                  _cancelEdit();
                                }
                              });
                              _saveDraft();
                            },
                            child: Icon(IconlyLight.delete,
                                color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const Spacer(),

          // Question input form
          if (!isComplete ||
              (_isEditMode && _editingLetterOrder == letterOrder)) ...[
            // Edit mode indicator
            if (_isEditMode && _editingLetterOrder == letterOrder) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(IconlyLight.edit,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Editing Question ${(_editingIndex ?? 0) + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                'Question ${currentIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _definitionController,
              decoration: InputDecoration(
                labelText: 'Definition (clue)',
                hintText: 'E.g., "A large gray animal"',
                prefixIcon: const Icon(IconlyLight.document),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: InputDecoration(
                labelText: 'Answer (must start with $letter)',
                hintText: 'E.g., "${letter}uck"',
                prefixIcon: const Icon(CupertinoIcons.lightbulb),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _addQuestion(letterOrder, letter),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              if (letterOrder > 1 && !_isEditMode)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _currentStep--);
                    },
                    child: const Text('Previous'),
                  ),
                ),
              if (letterOrder > 1 && !_isEditMode) const SizedBox(width: 12),
              // Cancel edit button
              if (_isEditMode && _editingLetterOrder == letterOrder)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                ),
              if (_isEditMode && _editingLetterOrder == letterOrder)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (isComplete &&
                          !(_isEditMode && _editingLetterOrder == letterOrder))
                      ? () {
                          setState(() => _currentStep++);
                          _saveDraft();
                        }
                      : (_definitionController.text.isNotEmpty &&
                              _answerController.text.isNotEmpty)
                          ? () => _addQuestion(letterOrder, letter)
                          : null,
                  child: Text((isComplete &&
                          !(_isEditMode && _editingLetterOrder == letterOrder))
                      ? 'Continue'
                      : (_isEditMode && _editingLetterOrder == letterOrder)
                          ? 'Update Question'
                          : 'Add Question'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  void _addQuestion(int letterOrder, String letter) {
    final definition = _definitionController.text.trim();
    final answer = _answerController.text.trim();

    if (definition.isEmpty || answer.isEmpty) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Please fill in both fields',
      );
      return;
    }

    // Validate answer starts with correct letter
    if (!answer.toUpperCase().startsWith(letter)) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Answer must start with letter $letter',
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      if (_isEditMode && _editingLetterOrder == letterOrder) {
        // UPDATE existing question
        _questions[letterOrder]![_editingIndex!] = QuestionDraft(
          definition: definition,
          answer: answer,
          letter: letter,
        );
        _editingLetterOrder = null;
        _editingIndex = null;
      } else {
        // ADD new question
        _questions[letterOrder]!.add(
          QuestionDraft(
            definition: definition,
            answer: answer,
            letter: letter,
          ),
        );
      }
      _definitionController.clear();
      _answerController.clear();
    });

    _saveDraft();
  }

  void _startEditingQuestion(int letterOrder, int index) {
    final questions = _questions[letterOrder]!;
    final question = questions[index];

    setState(() {
      _editingLetterOrder = letterOrder;
      _editingIndex = index;
      _definitionController.text = question.definition;
      _answerController.text = question.answer;

      // For random questions, also set the selected letter
      if (letterOrder == 4) {
        _selectedRandomLetter = question.letter;
      }
    });

    // Dismiss keyboard to prepare for editing
    FocusScope.of(context).unfocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingLetterOrder = null;
      _editingIndex = null;
      _definitionController.clear();
      _answerController.clear();
    });
  }

  Widget _buildRandomQuestions() {
    final randomQuestions = _questions[4] ?? [];
    final isComplete = randomQuestions.length >= widget.session.randomQuestionsCount;
    final totalQuestions =
        _questions.values.fold(0, (sum, list) => sum + list.length);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: LetterColors.random,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  IconlyLight.discovery,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Random Letters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${randomQuestions.length}/${widget.session.randomQuestionsCount} completed',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          LinearProgressIndicator(
            value: randomQuestions.length / widget.session.randomQuestionsCount,
            backgroundColor: Colors.grey[200],
            color: LetterColors.random,
          ),
          const SizedBox(height: 16),

          // Total progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: totalQuestions == widget.session.totalQuestionsRequired
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  totalQuestions == widget.session.totalQuestionsRequired
                      ? CupertinoIcons.checkmark_circle_fill
                      : IconlyLight.info_circle,
                  color: totalQuestions == widget.session.totalQuestionsRequired
                      ? AppColors.success
                      : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Total: $totalQuestions/${widget.session.totalQuestionsRequired} questions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: totalQuestions == widget.session.totalQuestionsRequired
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Random questions list
          if (randomQuestions.isNotEmpty) ...[
            Expanded(
              child: ListView.builder(
                itemCount: randomQuestions.length,
                itemBuilder: (context, index) {
                  final q = randomQuestions[index];
                  final isBeingEdited = _isEditMode &&
                      _editingLetterOrder == 4 &&
                      _editingIndex == index;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isBeingEdited
                        ? AppColors.primary.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: LetterColors.random,
                        child: Text(
                          q.letter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(q.definition,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('Answer: ${q.answer}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _startEditingQuestion(4, index),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(IconlyLight.edit,
                                  color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                randomQuestions.removeAt(index);
                                // Cancel edit if deleting the currently edited question
                                if (isBeingEdited) {
                                  _cancelEdit();
                                }
                              });
                              _saveDraft();
                            },
                            child: const Icon(IconlyLight.delete,
                                color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const Spacer(),

          // Add random question form
          if (!isComplete || (_isEditMode && _editingLetterOrder == 4)) ...[
            // Edit mode indicator
            if (_isEditMode && _editingLetterOrder == 4) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(IconlyLight.edit,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Editing Question ${(_editingIndex ?? 0) + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const Text(
                'Add Random Question',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Letter selection for random
            DropdownButtonFormField<String>(
              initialValue: _selectedRandomLetter,
              decoration: const InputDecoration(
                labelText: 'Select Letter',
                prefixIcon: Icon(CupertinoIcons.keyboard),
                suffixIcon: Icon(Icons.keyboard_arrow_down),
              ),
              items: AppConstants.alphabet
                  .map((letter) => DropdownMenuItem(
                        value: letter,
                        child: Text(letter),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedRandomLetter = value);
              },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _definitionController,
              decoration: const InputDecoration(
                labelText: 'Definition',
                prefixIcon: Icon(IconlyLight.document),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                prefixIcon: Icon(CupertinoIcons.lightbulb),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _addRandomQuestion(),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              if (!_isEditMode)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _currentStep = 3);
                    },
                    child: const Text('Previous'),
                  ),
                ),
              if (!_isEditMode) const SizedBox(width: 12),
              // Cancel edit button
              if (_isEditMode && _editingLetterOrder == 4)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                ),
              if (_isEditMode && _editingLetterOrder == 4)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (totalQuestions == widget.session.totalQuestionsRequired &&
                          !_isEditMode)
                      ? _submitAllQuestions
                      : (isComplete &&
                              !(_isEditMode && _editingLetterOrder == 4))
                          ? null
                          : _addRandomQuestion,
                  child: Text(
                    (totalQuestions == widget.session.totalQuestionsRequired &&
                            !_isEditMode)
                        ? 'Submit All'
                        : (_isEditMode && _editingLetterOrder == 4)
                            ? 'Update Question'
                            : 'Add Question',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String? _selectedRandomLetter;

  void _addRandomQuestion() {
    if (_selectedRandomLetter == null) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Please select a letter',
      );
      return;
    }

    final definition = _definitionController.text.trim();
    final answer = _answerController.text.trim();

    if (definition.isEmpty || answer.isEmpty) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Please fill in all fields',
      );
      return;
    }

    if (!answer.toUpperCase().startsWith(_selectedRandomLetter!)) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Answer must start with $_selectedRandomLetter',
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      if (_isEditMode && _editingLetterOrder == 4) {
        // UPDATE existing question
        _questions[4]![_editingIndex!] = QuestionDraft(
          definition: definition,
          answer: answer,
          letter: _selectedRandomLetter!,
        );
        _editingLetterOrder = null;
        _editingIndex = null;
      } else {
        // ADD new question
        _questions[4]!.add(
          QuestionDraft(
            definition: definition,
            answer: answer,
            letter: _selectedRandomLetter!,
          ),
        );
      }
      _definitionController.clear();
      _answerController.clear();
      _selectedRandomLetter = null;
    });

    _saveDraft();
  }

  Future<void> _submitAllQuestions() async {
    final result = await AsyncLoader.execute(
      context: context,
      message: 'Submitting questions...',
      asyncTask: () async {
        final currentUserId = ref.read(currentUserIdProvider);
        if (currentUserId == null) throw Exception('Not logged in');

        final firestoreService = ref.read(firestoreServiceProvider);

        // Convert drafts to Question models
        final List<Question> allQuestions = [];

        for (var letterOrder = 1; letterOrder <= 4; letterOrder++) {
          final letterQuestions = _questions[letterOrder] ?? [];
          for (var i = 0; i < letterQuestions.length; i++) {
            final draft = letterQuestions[i];
            allQuestions.add(
              Question(
                id: '',
                creatorId: currentUserId,
                letter: draft.letter,
                letterOrder: letterOrder,
                questionNumberInLetter: i + 1,
                definition: draft.definition,
                answer: draft.answer,
                isRandom: letterOrder == 4,
                createdAt: DateTime.now(),
              ),
            );
          }
        }

        // Submit to Firestore
        await firestoreService.submitQuestions(
          sessionId: widget.session.id,
          playerId: currentUserId,
          questions: allQuestions,
          selectedLetters: _selectedLetters,
        );

        // Clear draft
        final box = await Hive.openBox('question_drafts');
        await box.delete('${widget.session.id}_$currentUserId');

        return true;
      },
    );

    result.fold(
      (error) {
        if (mounted) {
          SnackBarHelper.showErrorSnackBar(
            context,
            'Error submitting: $error',
          );
        }
      },
      (_) {
        if (mounted) {
          SnackBarHelper.showSuccessSnackBar(
            context,
            'Questions submitted successfully!',
          );
          Navigator.of(context).pop();
        }
      },
    );
  }
}

class QuestionDraft {
  final String definition;
  final String answer;
  final String letter;

  QuestionDraft({
    required this.definition,
    required this.answer,
    required this.letter,
  });

  Map<String, dynamic> toMap() {
    return {
      'definition': definition,
      'answer': answer,
      'letter': letter,
    };
  }

  factory QuestionDraft.fromMap(Map<dynamic, dynamic> map) {
    return QuestionDraft(
      definition: map['definition'] ?? '',
      answer: map['answer'] ?? '',
      letter: map['letter'] ?? '',
    );
  }
}

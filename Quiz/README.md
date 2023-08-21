# Quiz
This flow implements the quiz logic, in the same way that it was implemented for [BWise](https://github.com/praekeltfoundation/vaccine-eligibility/blob/main/yal/quiz.py).

The base quiz tag, eg. `quiz_alcohol`, determines the parent content page, the children of which are the quiz questions.

The children of each question determine the multiple choice answers (and the content that should be sent in response to the user selecting that option).

The `quiz_end` tag marks the last question of the quiz.

The `score_xx`, eg. `score_1`, is the score that each question is worth

The `pass_percentage_xx`, eg. `pass_percentage_70`, determines the percentage (total score divided by number of questions) needed for a pass

The `<quiz_name>_pass`/`<quiz_name>_fail`, eg. `quiz_alcohol_pass`, are the pass/fail messages to send to the user depending on if they pass or fail. There can be `[SCORE]` text in that message body, which will get replaced with the score that the user achieved.


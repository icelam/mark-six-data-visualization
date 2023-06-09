import json
import os
import streamlit as st
import altair as alt
import pandas as pd
from datetime import datetime

@st.cache_data(ttl=3600)
def load_data(data_source):
    data = pd.read_json(data_source)
    data['date'] = pd.to_datetime(data['date']).dt.date
    data['no'] = data['no'].apply(lambda x: [int(i) for i in x])
    data['sno'] = pd.to_numeric(data['sno'])
    return data

@st.cache_data(ttl=3600, show_spinner=False)
def load_color_definations(data_source):
    with open(data_source, encoding='utf-8') as file:
        data = json.load(file)
        data_frame = pd.json_normalize(data)
    return data_frame

def remove_none_from_list(data):
    return list(filter(None, data))

ball_colors = load_color_definations(os.path.join(os.path.dirname(__file__), '../data/ball-colors.json'));

st.set_page_config(
    page_title="Mark Six Statistics",
    page_icon="🎱",
    layout="centered",
)
st.title('Mark Six Statistics')

st.markdown(
    'Mark Six (Chinese: 六合彩) is a lottery game organised by the Hong Kong Jockey Club. ' + \
    'The game is a 6-out-of-49 lottery-style game, with seven prize levels. ' + \
    'The winning numbers are selected automatically from a lottery machine that contains balls with numbers 1 to 49.'
)

# Load online so that we don't need to a re-deployment on data change
DATA_SOURCE = 'https://raw.githubusercontent.com/icelam/schedule-scrape-experiment/master/data/all.json'
mark_six_data = load_data(DATA_SOURCE)

dataset_last_updated = mark_six_data['date'].max().strftime('%Y/%m/%d');
number_of_records = len(mark_six_data.index);
st.caption(f'Dataset last updated on: {dataset_last_updated}, number of records: {number_of_records}')

tab1, tab2 = st.tabs(['Chart', 'Raw Data'])

with tab1:
    st.subheader('Occurrence of Balls')

    chart_option_column_1, chart_option_column_2, chart_option_column_3 = st.columns(3)

    min_data_date = mark_six_data['date'].min()
    max_data_date = mark_six_data['date'].max()
    date_range_to_display = chart_option_column_1.date_input(
        'Date Range',
        value=(min_data_date, max_data_date),
        min_value=min_data_date,
        max_value=max_data_date
    )

    group_by = chart_option_column_2.selectbox(
        'Group By',
        ('None', 'Odd / Even', 'Ball colors')
    )

    include_special_number = chart_option_column_3.selectbox(
        'Include special number',
        ('Yes', 'No')
    )

    # Insert spacing between option group and chart
    st.write('')

    filtered_mark_six_data = mark_six_data.copy()
    filtered_mark_six_data = filtered_mark_six_data[
        (filtered_mark_six_data['date'] >= date_range_to_display[0])
        & (filtered_mark_six_data['date'] <= date_range_to_display[-1])
    ]

    balls_summary = pd.DataFrame(list(range(1, 50)), columns=['ball'])

    balls_count = filtered_mark_six_data['no'].explode().value_counts().sort_index().to_frame()
    balls_count.insert(0, 'ball', balls_count.index)

    special_ball_count = filtered_mark_six_data['sno'].value_counts().sort_index().to_frame()
    special_ball_count.insert(0, 'ball', special_ball_count.index)

    balls_summary = balls_summary.merge(balls_count, on='ball', how='left')
    balls_summary = balls_summary.merge(special_ball_count, on='ball', how='left')

    balls_summary = balls_summary.rename(columns={ 'count_x': 'count', 'count_y': 'special_count' })
    balls_summary['special_count'].fillna(0, inplace=True)
    balls_summary['count'].fillna(0, inplace=True)

    balls_summary.insert(3, 'total_count', balls_summary['count'] + balls_summary['special_count'])
    balls_summary.insert(4, 'color', balls_summary['ball'].apply(lambda x: ball_colors[str(x)]))

    if group_by == 'Ball colors':
        balls_summary = balls_summary.groupby(by='color').sum()
        balls_summary.drop(columns='ball', inplace=True)
        balls_summary.insert(0, 'color', balls_summary.index)
    elif group_by == 'Odd / Even':
        balls_summary['parity'] = balls_summary.ball.apply(lambda x: 'odd' if x % 2 == 0 else 'even')
        balls_summary = balls_summary.groupby(by='parity').sum()
        balls_summary.sort_values(by='parity', ascending=False, inplace=True)
        balls_summary.insert(0, 'odd_or_even', balls_summary.index)

        balls_summary.drop(columns='color', inplace=True)
        balls_summary.drop(columns='ball', inplace=True)

    balls_summary.reset_index(inplace=True, drop=True)

    # A customized version of st.bar_chart(histogram_values)
    # List of ptions: https://altair-viz.github.io/user_guide/customization.html
    chart_data = (
        alt.Chart(balls_summary)
            .transform_fold(remove_none_from_list([
                'count',
                'special_count' if include_special_number == 'Yes' else None
            ]))
            .mark_bar()
            .configure_axis(grid=False)
            .configure_view(strokeWidth=0)
            .properties(height=500)
    )

    if group_by == 'None':
        chart_data = (
            chart_data.encode(
                x=alt.X('ball:O', title='Balls'),
                y=alt.Y('value:Q', title='Occurrence'),
                color=alt.Color(
                    'color',
                    scale=alt.Scale(
                        domain=['red', 'blue', 'green'],
                        range=['lightcoral', 'royalblue', 'mediumseagreen']
                    ),
                    legend=None
                ),
                opacity=alt.Opacity(
                    'value:Q',
                    legend=None
                ),
                tooltip=remove_none_from_list([
                    alt.Tooltip('ball', title='Ball'),
                    alt.Tooltip('count', title='Occurrence'),
                    alt.Tooltip('special_count', title='Occurrence (Special)') if include_special_number == 'Yes' else None,
                    alt.Tooltip('total_count', title='Total Occurrence') if include_special_number == 'Yes' else None
                ])
            )
        )
    elif group_by == 'Ball colors':
        chart_data = (
            chart_data.encode(
                x=alt.X('color:N', title='Color'),
                y=alt.Y('value:Q', title='Occurrence'),
                color=alt.Color(
                    'color',
                    scale=alt.Scale(
                        domain=['red', 'blue', 'green'],
                        range=['lightcoral', 'royalblue', 'mediumseagreen']
                    ),
                    legend=None
                ),
                opacity=alt.Opacity(
                    'value:Q',
                    legend=None
                ),
                tooltip=remove_none_from_list([
                    alt.Tooltip('color', title='Color'),
                    alt.Tooltip('count', title='Occurrence'),
                    alt.Tooltip('special_count', title='Occurrence (Special)') if include_special_number == 'Yes' else None,
                    alt.Tooltip('total_count', title='Total Occurrence') if include_special_number == 'Yes' else None
                ])
            )
        )
    elif group_by == 'Odd / Even':
        chart_data = (
            chart_data.encode(
                x=alt.X('odd_or_even:N', title='Odd / Even', sort="descending"),
                y=alt.Y('value:Q', title='Occurrence'),
                color=alt.Color(
                    'odd_or_even',
                    scale=alt.Scale(
                        domain=['odd', 'even'],
                        range=['lightcoral', 'royalblue']
                    ),
                    legend=None
                ),
                opacity=alt.Opacity(
                    'value:Q',
                    legend=None
                ),
                tooltip=remove_none_from_list([
                    alt.Tooltip('odd_or_even', title='Odd / Even'),
                    alt.Tooltip('count', title='Occurrence'),
                    alt.Tooltip('special_count', title='Occurrence (Special)') if include_special_number == 'Yes' else None,
                    alt.Tooltip('total_count', title='Total Occurrence') if include_special_number == 'Yes' else None
                ])
            )
        )

    st.altair_chart(chart_data, use_container_width=True)

    if st.checkbox('Show data'):
        st.write(balls_summary)

with tab2:
    st.write(mark_six_data)
